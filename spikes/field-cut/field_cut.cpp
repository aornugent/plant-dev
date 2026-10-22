// A toy stand whose cohorts shade and drink from one shared field, recorded once
// and swept twice: with the field responding (F_theta) and with every edge into
// the field cut (the selection gradient g), checked against an invader that reads
// the recorded field as doubles.
#include <XAD/XAD.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <vector>

#ifndef FD_H
#define FD_H 1e-7
#endif

using AD = xad::AReal<double>;
using Tape = xad::Tape<double>;

enum { GROWTH, SHADE, REPRO, LEAF, LNB, N_INPUT };
const char* input_name[N_INPUT] = {"growth", "shade_mortality", "alloc_repro",
                                   "leaf_area", "ln_b"};
constexpr int N_TRAIT = LNB;

struct Setup {
  int n = 24;
  int steps = 480;
  int intro_every = 12;
  double t_end = 40.0;
  double k = 0.6, eps = 0.25, mu0 = 0.04, h0 = 0.3, cu = 0.05, rw = 0.4, w0 = 1.0;

  double dt() const { return t_end / steps; }
  int active_at(int step) const { return std::min(n, step / intro_every + 1); }
  double establishment(int j) const { return std::exp(-0.03 * j * intro_every * dt()); }
  double weight(int j) const { return establishment(j) * intro_every * dt(); }
  std::size_t width() const { return 3 * n + 1; }  // (h, m, phi) per cohort, then W
};

template <class T> using Inputs = std::array<T, N_INPUT>;

// What a cohort's rates read and other cohorts make: each source's shading density
// and height, and the soil water.
template <class F>
struct Field {
  std::vector<F> D, H;
  F W;
};

template <class T, class F>
T light(const Setup& c, const Field<F>& f, const T& z) {
  T tau = 0.0;
  for (std::size_t j = 0; j < f.D.size(); ++j) {
    tau += f.D[j] / (1.0 + exp((z - f.H[j]) / c.eps));
  }
  return exp(-c.k * tau);
}

template <class T, class F>
void cohort_rates(const Setup& c, const Inputs<T>& p, const Field<F>& f,
                  const T* y, T* dy) {
  const T a = p[LEAF] * y[0];
  const T L = light(c, f, y[0]);
  const T P = L * a / (1.0 + a);
  dy[0] = p[GROWTH] * (1.0 - p[REPRO]) * P;
  dy[1] = -(c.mu0 + p[SHADE] * (1.0 - L));
  dy[2] = p[REPRO] * P * exp(y[1]) * f.W / (f.W + 0.5);
}

template <class T>
Field<T> build_field(const Setup& c, const Inputs<T>& p, const std::vector<T>& y,
                     int active) {
  Field<T> f;
  f.D.resize(active);
  f.H.resize(active);
  const T b = exp(p[LNB]);
  for (int j = 0; j < active; ++j) {
    f.D[j] = b * c.establishment(j) * exp(y[3 * j + 1]) * p[LEAF] * y[3 * j];
    f.H[j] = y[3 * j];
  }
  f.W = y[3 * c.n];
  return f;
}

template <class T, class Rates>
void rk4_step(const std::vector<T>& y0, double h, std::vector<T>& y1, Rates&& rates) {
  const std::size_t n = y0.size();
  std::vector<T> k1(n), k2(n), k3(n), k4(n), s(n);
  rates(y0, k1);
  for (std::size_t i = 0; i < n; ++i) s[i] = y0[i] + 0.5 * h * k1[i];
  rates(s, k2);
  for (std::size_t i = 0; i < n; ++i) s[i] = y0[i] + 0.5 * h * k2[i];
  rates(s, k3);
  for (std::size_t i = 0; i < n; ++i) s[i] = y0[i] + h * k3[i];
  rates(s, k4);
  y1.resize(n);
  for (std::size_t i = 0; i < n; ++i) {
    y1[i] = y0[i] + h / 6.0 * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i]);
  }
}

template <class T>
std::vector<T> initial_state(const Setup& c, std::size_t width) {
  std::vector<T> y(width, T(0.0));
  for (int j = 0; j < c.n; ++j) y[3 * j] = c.h0;
  if (width > std::size_t(3 * c.n)) y[3 * c.n] = c.w0;
  return y;
}

template <class T>
T log_offspring(const Setup& c, const std::vector<T>& y) {
  T J = 0.0;
  for (int j = 0; j < c.n; ++j) J += c.weight(j) * y[3 * j + 2];
  return log(J);
}

// One resident step. `on_field` sees each field as it is built, before any cohort
// reads it.
template <class T, class OnField>
void resident_step(const Setup& c, const Inputs<T>& p, int step,
                   const std::vector<T>& y0, std::vector<T>& y1, OnField&& on_field) {
  const int active = c.active_at(step);
  rk4_step(y0, c.dt(), y1, [&](const std::vector<T>& y, std::vector<T>& dy) {
    const Field<T> f = build_field(c, p, y, active);
    on_field(f);
    for (int i = 0; i < c.n; ++i) {
      if (i < active) {
        cohort_rates(c, p, f, &y[3 * i], &dy[3 * i]);
      } else {
        dy[3 * i] = dy[3 * i + 1] = dy[3 * i + 2] = 0.0;
      }
    }
    T uptake = 0.0;
    for (int j = 0; j < active; ++j) uptake += f.D[j];
    dy[3 * c.n] = c.rw * (1.0 - y[3 * c.n]) - c.cu * y[3 * c.n] * uptake;
  });
}

// F = ln J - ln b of the resident, with the state at every step boundary, the
// last included, in `states` if asked.
template <class T, class OnField>
T resident(const Setup& c, const Inputs<T>& p, OnField&& on_field,
           std::vector<std::vector<double>>* states = nullptr) {
  std::vector<T> y = initial_state<T>(c, c.width()), y1;
  auto keep = [&] {
    if (!states) return;
    states->emplace_back();
    for (const T& v : y) states->back().push_back(xad::value(v));
  };
  for (int k = 0; k < c.steps; ++k) {
    keep();
    resident_step(c, p, k, y, y1, on_field);
    std::swap(y, y1);
  }
  keep();
  return log_offspring(c, y);
}

// ln R' of a rare invader standing in the recorded field, one per rate evaluation.
// F is double for the invader plant runs today, and active to read the field's
// adjoints.
template <class T, class F>
T invader(const Setup& c, const Inputs<T>& p, const std::vector<Field<F>>& fields) {
  std::vector<T> y = initial_state<T>(c, 3 * c.n), y1;
  std::size_t at = 0;
  for (int k = 0; k < c.steps; ++k) {
    const int active = c.active_at(k);
    rk4_step(y, c.dt(), y1, [&](const std::vector<T>& s, std::vector<T>& ds) {
      const Field<F>& f = fields.at(at++);
      for (int i = 0; i < c.n; ++i) {
        if (i < active) {
          cohort_rates(c, p, f, &s[3 * i], &ds[3 * i]);
        } else {
          ds[3 * i] = ds[3 * i + 1] = ds[3 * i + 2] = 0.0;
        }
      }
    });
    std::swap(y, y1);
  }
  return log_offspring(c, y);
}

// Where a field was built on the tape, and the slots it was built into. A field
// value no input reaches has no slot and is listed as INVALID_SLOT.
struct Mark {
  Tape::position_type at;
  std::vector<Tape::slot_type> slots;
};

Mark mark_field(const Tape& tape, const Field<AD>& f) {
  Mark m{tape.getPosition(), {}};
  auto add = [&](const AD& x) { m.slots.push_back(x.getSlot()); };
  for (const AD& x : f.D) add(x);
  for (const AD& x : f.H) add(x);
  add(f.W);
  return m;
}

// The reverse pass with every field held fixed: sweep down to each field's mark,
// zero its adjoints before the statements that built it are reached, and truncate
// there. Without the truncation the next computeAdjointsTo rewalks the swept
// statements from the end, and a slot one of them reassigned now holds an adjoint
// for an earlier value, which it would propagate a second time. The recording is
// consumed, so this is the last sweep a recording gets. `held` receives the
// adjoint each field slot had when zeroed: the invader's field sensitivity.
void sweep_field_cut(Tape& tape, const std::vector<Mark>& marks, bool truncate,
                     std::vector<double>* held = nullptr) {
  for (auto m = marks.rbegin(); m != marks.rend(); ++m) {
    tape.computeAdjointsTo(m->at);
    for (Tape::slot_type s : m->slots) {
      const bool on_tape = s != AD::INVALID_SLOT;
      if (held) held->push_back(on_tape ? tape.derivative(s) : std::nan(""));
      if (on_tape) tape.derivative(s) = 0.0;
    }
    if (truncate) tape.resetTo(m->at);
  }
  tape.computeAdjoints();
}

using Clock = std::chrono::steady_clock;
double seconds_since(Clock::time_point t0) {
  return std::chrono::duration<double>(Clock::now() - t0).count();
}

double rel(double a, double b) {
  return std::abs(a - b) / std::max({std::abs(a), std::abs(b), 1e-300});
}

int main() {
  const Setup c;
  const Inputs<double> x0 = {1.2, 0.8, 0.3, 1.5, std::log(2.0)};
  const int repeats = 5;
  auto no_field = [](const auto&) {};

  // Resident in doubles, keeping the field at every rate evaluation.
  std::vector<Field<double>> fields;
  std::vector<std::vector<double>> states;
  double t_resident_double = 1e300;
  double F_double = 0.0;
  for (int r = 0; r < repeats; ++r) {
    fields.clear();
    states.clear();
    const auto t0 = Clock::now();
    F_double = resident(c, x0, [&](const Field<double>& f) { fields.push_back(f); },
                        &states);
    t_resident_double = std::min(t_resident_double, seconds_since(t0));
  }

  // One recording of the whole resident; pass 1 keeps the field, pass 2 cuts it.
  std::array<double, N_INPUT> F_theta{}, g_cut{}, g_naive{};
  std::vector<double> field_adjoint_cut;
  double F_ad = 0.0, t_record = 1e300, t_pass1 = 1e300, t_pass2 = 1e300;
  std::size_t statements = 0, n_marks = 0;
  for (int r = 0; r < repeats + 1; ++r) {
    const bool naive = r == repeats;  // pass 2 without truncation, for contrast
    Tape tape;
    Inputs<AD> p;
    for (int i = 0; i < N_INPUT; ++i) p[i] = x0[i];
    for (AD& v : p) tape.registerInput(v);
    tape.newRecording();
    std::vector<Mark> marks;
    auto t0 = Clock::now();
    AD F = resident(c, p, [&](const Field<AD>& f) { marks.push_back(mark_field(tape, f)); });
    tape.registerOutput(F);
    if (!naive) t_record = std::min(t_record, seconds_since(t0));
    statements = tape.getNumStatements();
    n_marks = marks.size();
    F_ad = xad::value(F);

    t0 = Clock::now();
    tape.clearDerivatives();
    xad::derivative(F) = 1.0;
    tape.computeAdjoints();
    if (!naive) t_pass1 = std::min(t_pass1, seconds_since(t0));
    for (int i = 0; i < N_INPUT; ++i) F_theta[i] = xad::derivative(p[i]);

    t0 = Clock::now();
    tape.clearDerivatives();
    xad::derivative(F) = 1.0;
    std::vector<double> held;
    sweep_field_cut(tape, marks, !naive, naive ? nullptr : &held);
    if (!naive) t_pass2 = std::min(t_pass2, seconds_since(t0));
    auto& into = naive ? g_naive : g_cut;
    for (int i = 0; i < N_INPUT; ++i) into[i] = xad::derivative(p[i]);
    if (!naive) field_adjoint_cut = std::move(held);
  }

  // The invader route: record the invader standing in the stored field, sweep it.
  std::array<double, N_TRAIT> g_inv{};
  double lnR_inv = 0.0, t_inv_record = 1e300, t_inv_sweep = 1e300;
  for (int r = 0; r < repeats; ++r) {
    Tape tape;
    Inputs<AD> p;
    for (int i = 0; i < N_INPUT; ++i) p[i] = x0[i];
    for (int i = 0; i < N_TRAIT; ++i) tape.registerInput(p[i]);
    tape.newRecording();
    auto t0 = Clock::now();
    AD lnR = invader(c, p, fields);
    tape.registerOutput(lnR);
    t_inv_record = std::min(t_inv_record, seconds_since(t0));
    t0 = Clock::now();
    xad::derivative(lnR) = 1.0;
    tape.computeAdjoints();
    t_inv_sweep = std::min(t_inv_sweep, seconds_since(t0));
    for (int i = 0; i < N_TRAIT; ++i) g_inv[i] = xad::derivative(p[i]);
    lnR_inv = xad::value(lnR);
  }

  // The same invader with its field active, for the field's own adjoints. The
  // marks were swept last to first, so they are reversed here to match.
  std::vector<double> field_adjoint_inv;
  {
    Tape tape;
    Inputs<AD> p;
    for (int i = 0; i < N_INPUT; ++i) p[i] = x0[i];
    std::vector<Field<AD>> active_fields(fields.size());
    for (std::size_t s = 0; s < fields.size(); ++s) {
      Field<AD>& a = active_fields[s];
      a.D.assign(fields[s].D.begin(), fields[s].D.end());
      a.H.assign(fields[s].H.begin(), fields[s].H.end());
      a.W = fields[s].W;
      for (AD& v : a.D) tape.registerInput(v);
      for (AD& v : a.H) tape.registerInput(v);
      tape.registerInput(a.W);
    }
    tape.newRecording();
    AD lnR = invader(c, p, active_fields);
    tape.registerOutput(lnR);
    xad::derivative(lnR) = 1.0;
    tape.computeAdjoints();
    for (auto f = active_fields.rbegin(); f != active_fields.rend(); ++f) {
      for (const AD& v : f->D) field_adjoint_inv.push_back(xad::derivative(v));
      for (const AD& v : f->H) field_adjoint_inv.push_back(xad::derivative(v));
      field_adjoint_inv.push_back(xad::derivative(f->W));
    }
  }

  // Step by step, as odelia sweeps: one recording per step from the stored state,
  // two adjoints carried down, the field-cut sweep last on each recording.
  std::array<double, N_INPUT> F_step{}, g_step{};
  std::array<double, 3> t_step = {1e300, 1e300, 1e300};  // record, pass 1, pass 2
  for (int r = 0; r < repeats; ++r) {
    std::array<double, 3> spent{};
    std::vector<double> lam_keep(c.width(), 0.0), lam_cut;
    double J = 0.0;
    for (int j = 0; j < c.n; ++j) J += c.weight(j) * states.back()[3 * j + 2];
    for (int j = 0; j < c.n; ++j) lam_keep[3 * j + 2] = c.weight(j) / J;
    lam_cut = lam_keep;
    F_step.fill(0.0);
    g_step.fill(0.0);
    Tape tape;
    for (int k = c.steps - 1; k >= 0; --k) {
      auto t0 = Clock::now();
      tape.clearAll();
      std::vector<AD> y(states[k].begin(), states[k].end()), y1;
      Inputs<AD> p;
      for (int i = 0; i < N_INPUT; ++i) p[i] = x0[i];
      tape.registerInputs(y);
      for (AD& v : p) tape.registerInput(v);
      tape.newRecording();
      std::vector<Mark> marks;
      resident_step(c, p, k, y, y1,
                    [&](const Field<AD>& f) { marks.push_back(mark_field(tape, f)); });
      tape.registerOutputs(y1);
      spent[0] += seconds_since(t0);

      t0 = Clock::now();
      tape.clearDerivatives();
      for (std::size_t i = 0; i < y1.size(); ++i) xad::derivative(y1[i]) = lam_keep[i];
      tape.computeAdjoints();
      for (std::size_t i = 0; i < y.size(); ++i) lam_keep[i] = xad::derivative(y[i]);
      for (int i = 0; i < N_INPUT; ++i) F_step[i] += xad::derivative(p[i]);
      spent[1] += seconds_since(t0);

      t0 = Clock::now();
      tape.clearDerivatives();
      for (std::size_t i = 0; i < y1.size(); ++i) xad::derivative(y1[i]) = lam_cut[i];
      sweep_field_cut(tape, marks, true);
      for (std::size_t i = 0; i < y.size(); ++i) lam_cut[i] = xad::derivative(y[i]);
      for (int i = 0; i < N_INPUT; ++i) g_step[i] += xad::derivative(p[i]);
      spent[2] += seconds_since(t0);
    }
    for (int i = 0; i < 3; ++i) t_step[i] = std::min(t_step[i], spent[i]);
  }

  // Central differences of the resident (field responding) and of the invader.
  std::array<double, N_INPUT> F_fd{}, g_fd{};
  for (int i = 0; i < N_INPUT; ++i) {
    const double h = FD_H * std::max(1.0, std::abs(x0[i]));
    Inputs<double> up = x0, dn = x0;
    up[i] += h;
    dn[i] -= h;
    F_fd[i] = (resident(c, up, no_field) - resident(c, dn, no_field)) / (2 * h);
    if (i < N_TRAIT) g_fd[i] = (invader(c, up, fields) - invader(c, dn, fields)) / (2 * h);
  }

  std::printf("cohorts %d, steps %d, rate evaluations %zu, tape statements %zu\n\n",
              c.n, c.steps, n_marks, statements);
  std::printf("F = ln J - ln b: double %.17g, active %.17g\n", F_double, F_ad);
  std::printf("ln R' (invader at theta' = theta) %.17g, rel diff to F %.2e\n\n",
              lnR_inv, rel(lnR_inv, F_double));

  std::printf("%-16s %13s %9s %13s %13s %9s %9s %13s %9s %9s\n", "input",
              "F_theta pass1", "vs FD", "g pass2 cut", "g invader", "cut-inv",
              "inv vs FD", "commons F-g", "step F", "step g");
  for (int i = 0; i < N_INPUT; ++i) {
    const bool trait = i < N_TRAIT;
    std::printf("%-16s %13.6e %9.1e %13.6e ", input_name[i], F_theta[i],
                rel(F_theta[i], F_fd[i]), g_cut[i]);
    if (trait) {
      std::printf("%13.6e %9.1e %9.1e ", g_inv[i], rel(g_cut[i], g_inv[i]),
                  rel(g_inv[i], g_fd[i]));
    } else {
      std::printf("%13s %9s %9s ", "-", "-", "-");
    }
    std::printf("%13.6e %9.1e %9.1e\n", F_theta[i] - g_cut[i], rel(F_step[i], F_theta[i]),
                rel(g_step[i], g_cut[i]));
  }

  double worst_field = 0.0, biggest = 0.0;
  std::size_t compared = 0;
  for (double v : field_adjoint_inv) biggest = std::max(biggest, std::abs(v));
  for (std::size_t s = 0; s < field_adjoint_inv.size(); ++s) {
    if (std::isnan(field_adjoint_cut.at(s))) continue;
    ++compared;
    worst_field = std::max(worst_field,
                           std::abs(field_adjoint_cut[s] - field_adjoint_inv[s]) / biggest);
  }
  std::printf("\nfield adjoints zeroed in pass 2 vs invader's d ln R'/d field: %zu values, "
              "max |diff| / max|adjoint| %.1e\n",
              compared, worst_field);
  std::printf("pass 2 without truncation (rewalks swept statements):");
  for (int i = 0; i < N_TRAIT; ++i) std::printf(" %.3e", g_naive[i]);
  std::printf("  (g per trait; wrong)\n\n");

  const double t_inv = t_resident_double + t_inv_record + t_inv_sweep;
  std::printf("timings (min of %d), seconds:\n", repeats);
  std::printf("  resident record          %.4f\n", t_record);
  std::printf("  pass 1 (field kept)      %.4f\n", t_pass1);
  std::printf("  pass 2 (field cut)       %.4f   = %.2f x pass 1\n", t_pass2, t_pass2 / t_pass1);
  std::printf("  invader route            %.4f   = %.2f x pass 2  (double resident %.4f + "
              "record %.4f + sweep %.4f)\n",
              t_inv, t_inv / t_pass2, t_resident_double, t_inv_record, t_inv_sweep);
  std::printf("  invader record + sweep   %.4f   = %.2f x pass 2\n",
              t_inv_record + t_inv_sweep, (t_inv_record + t_inv_sweep) / t_pass2);
  std::printf("  step by step: record %.4f, pass 1 %.4f, pass 2 %.4f = %.2f x pass 1\n",
              t_step[0], t_step[1], t_step[2], t_step[2] / t_step[1]);
  return 0;
}
