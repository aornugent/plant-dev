// The singular strategy of the toy stand found two ways: an equilibrium solved
// inside every evolutionary step, and one recording per step that moves birth rate
// and traits together. Then, for two species, the birth-rate Jacobian and every
// species' selection gradient from one recording.
#include "toy.hpp"

#include <cstdio>
#include <functional>
#include <string>

constexpr std::array<int, 2> EVOLVED = {REPRO, LEAF};
constexpr int K = EVOLVED.size();

using Vec = std::vector<double>;
using Mat = std::vector<Vec>;

Vec solve(Mat A, Vec b) {
  const std::size_t n = b.size();
  for (std::size_t i = 0; i < n; ++i) {
    std::size_t piv = i;
    for (std::size_t r = i + 1; r < n; ++r) {
      if (std::abs(A[r][i]) > std::abs(A[piv][i])) piv = r;
    }
    std::swap(A[i], A[piv]);
    std::swap(b[i], b[piv]);
    for (std::size_t r = i + 1; r < n; ++r) {
      const double f = A[r][i] / A[i][i];
      for (std::size_t k = i; k < n; ++k) A[r][k] -= f * A[i][k];
      b[r] -= f * b[i];
    }
  }
  Vec x(n);
  for (std::size_t i = n; i-- > 0;) {
    double s = b[i];
    for (std::size_t k = i + 1; k < n; ++k) s -= A[i][k] * x[k];
    x[i] = s / A[i][i];
  }
  return x;
}

double max_abs(const Vec& v) {
  double m = 0.0;
  for (double x : v) m = std::max(m, std::abs(x));
  return m;
}

// Birth rates and evolved traits of every species; the other inputs stay at `base`.
// Traits evolve on an unbounded scale: allocation as its logit, leaf area as its log.
struct Point {
  Vec lnb, theta;  // m, then m * K species-major
};

double trait(int t, double u) { return t == 0 ? 1.0 / (1.0 + std::exp(-u)) : std::exp(u); }
double trait_scale(int t, double u) {  // d trait / d u
  const double v = trait(t, u);
  return t == 0 ? v * (1.0 - v) : v;
}
double unscaled(int t, double v) { return t == 0 ? std::log(v / (1.0 - v)) : std::log(v); }

std::vector<Inputs<double>> stand_inputs(const std::vector<Inputs<double>>& base,
                                         const Point& x) {
  auto p = base;
  for (std::size_t s = 0; s < p.size(); ++s) {
    p[s][LNB] = x.lnb[s];
    for (int t = 0; t < K; ++t) p[s][EVOLVED[t]] = trait(t, x.theta[s * K + t]);
  }
  return p;
}

// Newton's step on F in ln b, capped at 1 in every species.
void newton_birth_rates(const Mat& Fb, const Vec& rhs, Vec& lnb) {
  const Vec d = solve(Fb, rhs);
  const double big = max_abs(d);
  for (std::size_t s = 0; s < d.size(); ++s) lnb[s] -= big > 1.0 ? d[s] / big : d[s];
}

struct Cost {
  int runs = 0;     // forward runs in doubles
  int records = 0;  // taped forward runs
  int sweeps = 0;   // reverse passes, field kept or cut
  double seconds = 0.0;
};

// What one recording returns: F_i, dF_i/d ln b_j, dF_i/d theta_j with the field
// responding, and g_j with it held. One kept sweep per species, then one cut
// sweep of the sum of all F_i: with the field held, F_i reaches no other
// species' inputs, so that sweep's adjoint on species j's traits is g_j.
struct Taped {
  Vec F, g, ln_b_cut;
  Mat Fb, Fth;
};

Taped record(const Setup& c, const std::vector<Inputs<double>>& base, const Point& x,
             Cost& cost) {
  const auto t0 = Clock::now();
  const int m = c.species;
  Tape tape;
  std::vector<Inputs<AD>> p(m);
  const auto values = stand_inputs(base, x);
  for (int s = 0; s < m; ++s) {
    for (int i = 0; i < N_INPUT; ++i) p[s][i] = values[s][i];
    for (AD& v : p[s]) tape.registerInput(v);
  }
  tape.newRecording();
  std::vector<Mark> marks;
  std::vector<AD> F = resident(c, p, [&](const Field<AD>& f) {
    marks.push_back(mark_field(tape, f));
  });
  tape.registerOutputs(F);
  ++cost.records;

  Taped out;
  out.Fb.assign(m, Vec(m));
  out.Fth.assign(m, Vec(m * K));
  for (int i = 0; i < m; ++i) {
    out.F.push_back(xad::value(F[i]));
    tape.clearDerivatives();
    xad::derivative(F[i]) = 1.0;
    tape.computeAdjoints();
    for (int s = 0; s < m; ++s) {
      out.Fb[i][s] = xad::derivative(p[s][LNB]);
      for (int t = 0; t < K; ++t) {
        out.Fth[i][s * K + t] = xad::derivative(p[s][EVOLVED[t]]) *
                                trait_scale(t, x.theta[s * K + t]);
      }
    }
  }
  tape.clearDerivatives();
  for (AD& f : F) xad::derivative(f) = 1.0;
  sweep_field_cut(tape, marks, true);
  for (int s = 0; s < m; ++s) {
    out.ln_b_cut.push_back(xad::derivative(p[s][LNB]));
    for (int t = 0; t < K; ++t) {
      out.g.push_back(xad::derivative(p[s][EVOLVED[t]]) * trait_scale(t, x.theta[s * K + t]));
    }
  }
  cost.sweeps += m + 1;
  cost.seconds += seconds_since(t0);
  return out;
}

Vec run(const Setup& c, const std::vector<Inputs<double>>& base, const Point& x,
        Cost& cost, std::vector<Field<double>>* fields = nullptr) {
  const auto t0 = Clock::now();
  Vec F = resident(c, stand_inputs(base, x), [&](const Field<double>& f) {
    if (fields) fields->push_back(f);
  });
  ++cost.runs;
  cost.seconds += seconds_since(t0);
  return F;
}

// The traits' quasi-Newton step on g = 0: Broyden's update of the reduced
// Jacobian from the previous step, then a step capped at `cap` in every trait. A
// step against selection restarts from steepest ascent, so the search follows
// adaptive dynamics to a convergence-stable point.
struct Broyden {
  Mat B;
  Vec s, g;
  double scale, cap;
  Broyden(int n, double scale, double cap) : scale(scale), cap(cap) { reset(n); }
  void reset(int n) {
    B.assign(n, Vec(n, 0.0));
    for (int i = 0; i < n; ++i) B[i][i] = -scale;
  }
  Vec step(const Vec& g_now) {
    const std::size_t n = g_now.size();
    if (!s.empty()) {
      double ss = 0.0;
      for (double v : s) ss += v * v;
      for (std::size_t i = 0; i < n; ++i) {
        double r = g_now[i] - g[i];
        for (std::size_t j = 0; j < n; ++j) r -= B[i][j] * s[j];
        for (std::size_t j = 0; j < n; ++j) B[i][j] += r * s[j] / ss;
      }
    }
    Vec d = solve(B, g_now);
    for (double& v : d) v = -v;
    double ascent = 0.0;
    for (std::size_t i = 0; i < n; ++i) ascent += d[i] * g_now[i];
    if (ascent <= 0.0) {
      reset(n);
      for (std::size_t i = 0; i < n; ++i) d[i] = g_now[i] / scale;
    }
    const double big = max_abs(d);
    if (big > cap) {
      for (double& v : d) v *= cap / big;
    }
    s = d;
    g = g_now;
    return d;
  }
};

struct Tolerance {
  double F = 1e-10, g = 1e-8;
  int max_outer = 200, max_inner = 500;
};

struct Outcome {
  std::string name;
  Point x;
  Vec F, g;
  int outer = 0;
  Cost cost;
};

// regnans's iteration: offspring out become seed in, ln b <- ln b + F.
void equilibrium_by_iteration(const Setup& c, const std::vector<Inputs<double>>& base,
                              Point& x, double tol, int max_inner, Cost& cost) {
  for (int i = 0; i < max_inner; ++i) {
    const Vec F = run(c, base, x, cost);
    if (max_abs(F) < tol) return;
    for (std::size_t s = 0; s < F.size(); ++s) x.lnb[s] += F[s];
  }
}

Outcome nested(const std::string& name, const Setup& c,
               const std::vector<Inputs<double>>& base, Point x, bool newton,
               double eq_tol, const Tolerance& tol, double scale, double cap) {
  Outcome o{name};
  Broyden outer(x.theta.size(), scale, cap);
  for (o.outer = 1; o.outer <= tol.max_outer; ++o.outer) {
    if (!newton) equilibrium_by_iteration(c, base, x, eq_tol, tol.max_inner, o.cost);
    Taped t = record(c, base, x, o.cost);
    for (int i = 0; newton && max_abs(t.F) >= eq_tol && i < tol.max_inner; ++i) {
      newton_birth_rates(t.Fb, t.F, x.lnb);
      t = record(c, base, x, o.cost);
    }
    o.F = t.F;
    o.g = t.g;
    if (max_abs(t.F) < tol.F && max_abs(t.g) < tol.g) break;
    if (max_abs(t.g) < tol.g) continue;  // only the equilibrium is short
    const Vec d = outer.step(t.g);
    for (std::size_t i = 0; i < d.size(); ++i) x.theta[i] += d[i];
  }
  o.x = x;
  return o;
}

// One recording per step. The traits take the same quasi-Newton step on g; birth
// rates take Newton's step on F, predicted along that trait step through the
// field-kept F_theta, so they stay on the linearised equilibrium as traits move.
Outcome one_shot(const std::string& name, const Setup& c,
                 const std::vector<Inputs<double>>& base, Point x, bool predict,
                 const Tolerance& tol, double scale, double cap) {
  Outcome o{name};
  Broyden outer(x.theta.size(), scale, cap);
  for (o.outer = 1; o.outer <= tol.max_outer; ++o.outer) {
    const Taped t = record(c, base, x, o.cost);
    o.F = t.F;
    o.g = t.g;
    if (max_abs(t.F) < tol.F && max_abs(t.g) < tol.g) break;
    const Vec d = max_abs(t.g) < tol.g ? Vec(t.g.size(), 0.0) : outer.step(t.g);
    Vec rhs = t.F;
    for (std::size_t i = 0; predict && i < rhs.size(); ++i) {
      for (std::size_t j = 0; j < d.size(); ++j) rhs[i] += t.Fth[i][j] * d[j];
    }
    newton_birth_rates(t.Fb, rhs, x.lnb);
    for (std::size_t i = 0; i < d.size(); ++i) x.theta[i] += d[i];
  }
  o.x = x;
  return o;
}

void print(const Outcome& o) {
  std::printf("%-34s %4d %5d %5d %5d %8.3f   ", o.name.c_str(), o.outer, o.cost.runs,
              o.cost.records, o.cost.sweeps, o.cost.seconds);
  for (std::size_t i = 0; i < o.x.theta.size(); ++i) {
    std::printf("%.10f ", trait(i % K, o.x.theta[i]));
  }
  for (double v : o.x.lnb) std::printf("%.10f ", v);
  std::printf("  |F| %.0e |g| %.0e\n", max_abs(o.F), max_abs(o.g));
}

// The singular strategy by central differences on the evolving scale: the invader's
// Hessian in the held field (negative definite is an ESS) and the Jacobian of g
// with the equilibrium re-solved (eigenvalues with negative real part is
// convergence stable).
Vec classify(const Setup& c, const std::vector<Inputs<double>>& base, const Point& x) {
  Cost cost;
  std::vector<Field<double>> fields;
  run(c, base, x, cost, &fields);
  const double h = 1e-3;
  auto lnR = [&](double di, double dj, int i, int j) {
    Point y = x;
    y.theta[i] += di;
    y.theta[j] += dj;
    return invader(c, stand_inputs(base, y)[0], fields);
  };
  auto g_at_equilibrium = [&](int i, double d) {
    Point y = x;
    y.theta[i] += d;
    Taped t = record(c, base, y, cost);
    while (max_abs(t.F) >= 1e-12) {
      newton_birth_rates(t.Fb, t.F, y.lnb);
      t = record(c, base, y, cost);
    }
    return t.g;
  };
  Mat H(K, Vec(K)), J(K, Vec(K));
  for (int i = 0; i < K; ++i) {
    for (int j = 0; j < K; ++j) {
      H[i][j] = (lnR(h, h, i, j) - lnR(h, -h, i, j) - lnR(-h, h, i, j) + lnR(-h, -h, i, j)) /
                (4 * h * h);
    }
    const Vec up = g_at_equilibrium(i, h), dn = g_at_equilibrium(i, -h);
    for (int r = 0; r < K; ++r) J[r][i] = (up[r] - dn[r]) / (2 * h);
  }
  auto eigen = [](const Mat& A, const char* name) {
    const double tr = A[0][0] + A[1][1], det = A[0][0] * A[1][1] - A[0][1] * A[1][0];
    const double disc = tr * tr / 4 - det;
    if (disc >= 0) {
      std::printf("  %s eigenvalues %.4g, %.4g\n", name, tr / 2 - std::sqrt(disc),
                  tr / 2 + std::sqrt(disc));
    } else {
      std::printf("  %s eigenvalues %.4g +- %.4gi\n", name, tr / 2, std::sqrt(-disc));
    }
    return std::make_pair(tr, det);
  };
  std::printf("the singular strategy:\n");
  const auto [htr, hdet] = eigen(H, "invader Hessian, field held         ");
  const auto [jtr, jdet] = eigen(J, "Jacobian of g, equilibrium re-solved");
  const bool ess = htr < 0 && hdet > 0, css = jtr < 0 && jdet > 0;
  std::printf("  %s, %s: %s\n", ess ? "an ESS" : "not an ESS",
              css ? "convergence stable" : "not convergence stable",
              ess && css ? "an endpoint" : css ? "a branching point" : "a repeller");
  // The direction of the Hessian's larger eigenvalue, along which a pair splits.
  const double top = htr / 2 + std::sqrt(std::max(0.0, htr * htr / 4 - hdet));
  Vec v = std::abs(H[0][1]) > 1e-12 ? Vec{H[0][1], top - H[0][0]}
                                    : (H[0][0] >= H[1][1] ? Vec{1.0, 0.0} : Vec{0.0, 1.0});
  const double norm = std::hypot(v[0], v[1]);
  for (double& e : v) e /= norm;
  return v;
}

// Two residents split from the branching point along `v`, then the pair's singular
// coalition found nested and with one recording per step.
void coalition(const Setup& one, const std::vector<Inputs<double>>& base, const Point& x,
               const Vec& v, const Tolerance& tol, double scale, double cap) {
  Setup c = one;
  c.species = 2;
  const std::vector<Inputs<double>> pair = {base[0], base[0]};
  const double split = 0.1;
  Point start{{x.lnb[0] - std::log(2.0), x.lnb[0] - std::log(2.0)}, {}};
  for (double sign : {1.0, -1.0}) {
    for (int t = 0; t < K; ++t) start.theta.push_back(x.theta[t] + sign * split * v[t]);
  }
  std::printf("\nTwo residents split by %.2f from it along (%.3f, %.3f):\n", split, v[0], v[1]);
  std::printf("%-34s %4s %5s %5s %5s %8s   %s\n", "route", "step", "runs", "rec", "sweep",
              "seconds", "theta*_1, theta*_2, ln b*");
  const std::vector<Outcome> all = {
      nested("nested, iteration (regnans)", c, pair, start, false, tol.F, tol, scale, cap),
      nested("nested, Newton on taped dF/dlnb", c, pair, start, true, tol.F, tol, scale, cap),
      one_shot("one recording per step", c, pair, start, true, tol, scale, cap),
  };
  for (const Outcome& o : all) print(o);
  double spread = 0.0;
  for (const Outcome& o : all) {
    if (!std::isfinite(o.x.lnb[0] + o.x.lnb[1])) {
      std::printf("%s: failed, birth rates not finite\n", o.name.c_str());
      continue;
    }
    for (std::size_t i = 0; i < o.x.theta.size(); ++i) {
      spread = std::max(spread, std::abs(o.x.theta[i] - all[0].x.theta[i]));
    }
    for (std::size_t s = 0; s < o.x.lnb.size(); ++s) {
      spread = std::max(spread, std::abs(o.x.lnb[s] - all[0].x.lnb[s]));
    }
  }
  std::printf("largest difference between the finished routes' answers: %.1e\n", spread);
}

void two_species() {
  Setup c;
  c.species = 2;
  c.leaf_cost = 0.4;
  const std::vector<Inputs<double>> base = {{1.2, 0.8, 0.3, 1.5, 0.0},
                                            {1.0, 0.5, 0.45, 2.5, 0.0}};
  Point x{{std::log(2.0), std::log(0.5)},
          {unscaled(0, 0.3), unscaled(1, 1.5), unscaled(0, 0.45), unscaled(1, 2.5)}};

  std::printf("\nTwo species, traits held: the equilibrium both ways, then one recording "
              "at it.\n");
  Point fp = x;
  Cost cost_fp;
  equilibrium_by_iteration(c, base, fp, 1e-10, 2000, cost_fp);
  Point nt = x;
  Cost cost_nt;
  Taped t = record(c, base, nt, cost_nt);
  while (max_abs(t.F) >= 1e-10 && cost_nt.records < 50) {
    newton_birth_rates(t.Fb, t.F, nt.lnb);
    t = record(c, base, nt, cost_nt);
  }
  std::printf("  iteration ln b <- ln b + F: %d runs, b = (%.10f, %.10f)\n", cost_fp.runs,
              std::exp(fp.lnb[0]), std::exp(fp.lnb[1]));
  std::printf("  Newton with the taped dF/d ln b: %d recordings, b = (%.10f, %.10f), "
              "|F| %.0e\n",
              cost_nt.records, std::exp(nt.lnb[0]), std::exp(nt.lnb[1]), max_abs(t.F));

  Cost scratch;
  const double h = 1e-6;
  std::printf("  dF_i/d ln b_j, taped against central differences:\n");
  for (int j = 0; j < 2; ++j) {
    Point up = nt, dn = nt;
    up.lnb[j] += h;
    dn.lnb[j] -= h;
    const Vec Fu = run(c, base, up, scratch), Fd = run(c, base, dn, scratch);
    for (int i = 0; i < 2; ++i) {
      const double fd = (Fu[i] - Fd[i]) / (2 * h);
      std::printf("    i=%d j=%d  %13.6e  %13.6e  rel %.1e\n", i, j, t.Fb[i][j], fd,
                  rel(t.Fb[i][j], fd));
    }
  }
  std::printf("  det dF/d ln b = %.4f\n", t.Fb[0][0] * t.Fb[1][1] - t.Fb[0][1] * t.Fb[1][0]);

  std::vector<Field<double>> fields;
  run(c, base, nt, scratch, &fields);
  const auto values = stand_inputs(base, nt);
  std::printf("  g from one cut sweep of F_1 + F_2, against each species' invader:\n");
  for (int s = 0; s < 2; ++s) {
    Tape tape;
    Inputs<AD> p;
    for (int i = 0; i < N_INPUT; ++i) p[i] = values[s][i];
    for (AD& v : p) tape.registerInput(v);
    tape.newRecording();
    AD lnR = invader(c, p, fields);
    tape.registerOutput(lnR);
    xad::derivative(lnR) = 1.0;
    tape.computeAdjoints();
    for (int k = 0; k < K; ++k) {
      const double gi = xad::derivative(p[EVOLVED[k]]) * trait_scale(k, nt.theta[s * K + k]);
      std::printf("    species %d %-12s cut %13.6e  invader %13.6e  rel %.1e\n", s + 1,
                  input_name[EVOLVED[k]], t.g[s * K + k], gi, rel(t.g[s * K + k], gi));
    }
    std::printf("    species %d ln R' %.3e against F %.3e; ln b in the cut sweep %.1e\n",
                s + 1, xad::value(lnR), t.F[s], t.ln_b_cut[s]);
  }
}

int main() {
  Setup c;
  c.leaf_cost = 0.4;
  const std::vector<Inputs<double>> base = {{1.2, 0.8, 0.3, 1.5, 0.0}};
  const Point start{{std::log(2.0)}, {unscaled(0, 0.3), unscaled(1, 1.5)}};
  const Tolerance tol;
  const double scale = 10.0, cap = 0.25;

  std::printf("One species, traits %s and %s evolving; leaf cost %.2f.\n",
              input_name[EVOLVED[0]], input_name[EVOLVED[1]], c.leaf_cost);
  std::printf("Stop when |F| < %.0e and |g| < %.0e at one point.\n\n", tol.F, tol.g);
  std::printf("%-34s %4s %5s %5s %5s %8s   %s\n", "route", "step", "runs", "rec", "sweep",
              "seconds", "theta*, ln b*");
  const std::vector<Outcome> all = {
      nested("nested, iteration (regnans)", c, base, start, false, tol.F, tol, scale, cap),
      nested("nested, Newton on taped dF/dlnb", c, base, start, true, tol.F, tol, scale, cap),
      one_shot("one recording per step", c, base, start, true, tol, scale, cap),
      one_shot("  same, without the F_theta term", c, base, start, false, tol, scale, cap),
  };
  for (const Outcome& o : all) print(o);
  double spread = 0.0;
  for (const Outcome& o : all) {
    for (std::size_t i = 0; i < o.x.theta.size(); ++i) {
      spread = std::max(spread, std::abs(o.x.theta[i] - all[0].x.theta[i]));
    }
    spread = std::max(spread, std::abs(o.x.lnb[0] - all[0].x.lnb[0]));
  }
  std::printf("largest difference between routes' answers: %.1e\n", spread);
  const Vec v = classify(c, base, all[2].x);
  coalition(c, base, all[2].x, v, tol, scale, cap);

  two_species();
  return 0;
}
