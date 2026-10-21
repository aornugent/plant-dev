// [[Rcpp::plugins(cpp20)]]
// [[Rcpp::depends(plant, odelia, phylloptim, BH)]]
#include <plant.h>
#include <chrono>

using A = xad::AReal<double>;
using Tape = xad::Tape<double>;

template <class Strat, class Env>
void setup(Strat& s, Env& env) {}

// Light field: 65 knots over [0, 20], E = exp(-k*(20-h)) style, with slopes.
static std::vector<double> field_state() {
  const int n = 65; std::vector<double> x(n), y(n), m(n);
  for (int i = 0; i < n; ++i) {
    x[i] = 20.0 * i / (n - 1);
    y[i] = std::exp(-0.08 * (20.0 - x[i]));
    m[i] = 0.08 * y[i];
  }
  std::vector<double> st(x); st.insert(st.end(), y.begin(), y.end());
  st.insert(st.end(), m.begin(), m.end());
  return st;
}

// [[Rcpp::export]]
Rcpp::List crown_cost(int reps, double h0) {
  plant::FF16_Strategy<double> sd;
  sd.prepare_strategy();
  plant::FF16_Environment<double> ed;
  ed.r_init_interpolators(field_state());

  // double: one crown integral
  double sink = 0;
  auto t0 = std::chrono::steady_clock::now();
  for (int r = 0; r < reps; ++r) {
    const double h = h0 * (1 + 1e-9 * r);
    sink += sd.assimilation(ed, h, sd.area_leaf(h), 1.0 / h);
  }
  double t_double = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count() / reps;

  Tape tape;
  plant::FF16_Strategy<A> sa = sd.template rebind_from<A>();
  plant::FF16_Environment<A> ea = ed.template rebind_from<A>();
  ea.r_init_interpolators(field_state());
  for (A* p : sa.ad_parameters()) tape.registerInput(*p);
  ea.for_each_active([&](A& x) { tape.registerInput(x); });

  // statement count for one integral
  A h = h0; tape.registerInput(h);
  tape.newRecording();
  auto pos0 = tape.getPosition();
  auto st0 = tape.getNumStatements(), op0 = tape.getNumOperations();
  A al = sa.area_leaf(h);
  auto st1 = tape.getNumStatements();
  A hi = 1.0 / h;
  A out = sa.assimilation(ea, h, al, hi);
  auto st2 = tape.getNumStatements(), op2 = tape.getNumOperations();
  tape.registerOutput(out);
  xad::derivative(out) = 1.0;
  tape.computeAdjoints();
  const double dAdh = xad::derivative(h);

  // record + sweep timing per integral
  double t_rec = 0, t_sweep = 0;
  for (int r = 0; r < reps; ++r) {
    tape.resetTo(pos0);
    auto a = std::chrono::steady_clock::now();
    A o = sa.assimilation(ea, h, al, hi);
    auto b = std::chrono::steady_clock::now();
    xad::derivative(o) = 1.0;
    tape.computeAdjointsTo(pos0);
    auto c = std::chrono::steady_clock::now();
    tape.clearDerivatives();
    t_rec += std::chrono::duration<double>(b - a).count();
    t_sweep += std::chrono::duration<double>(c - b).count();
  }

  // Folded integrand: z_j = h s_j, so q's shape factor is a per-node constant
  // and half_length / z_j = 1 / (2 s_j). One spline read, one leaf rate and one
  // accumulate per node.
  plant::quadrature::QK qk(sd.control.function_integration_rule);
  const std::vector<double> s_nodes = qk.integrate_vector_x(0.0, 1.0);
  const size_t nn = s_nodes.size();
  std::vector<double> c(nn);
  const double eta = 12.0;
  for (size_t j = 0; j < nn; ++j) {
    std::vector<double> e(nn, 0.0); e[j] = 1.0;
    const double w = qk.integrate_vector(e, 0.0, 1.0);
    const double ue = std::pow(s_nodes[j], eta);
    c[j] = w * 2.0 * eta * (1.0 - ue) * ue / s_nodes[j];
  }
  const double cap = ea.max_environment_height();
  auto folded_on = [&](auto& st, auto& en, const A& hh, const A& alv) {
    A acc = 0.0;
    for (size_t j = 0; j < nn; ++j) {
      acc += c[j] * st.assimilation_leaf(en.get_environment_at_height(hh * s_nodes[j], cap));
    }
    return A(alv * acc);
  };
  auto folded = [&](const A& hh, const A& alv) { return folded_on(sa, ea, hh, alv); };
  // Both arms from a fresh recording, h and area_leaf registered separately,
  // so each derivative is the integral's own.
  auto grad = [&](auto&& F) {
    tape.deactivate();
    std::vector<double> ret;
    {
    Tape t2;
    plant::FF16_Strategy<A> s2 = sd.template rebind_from<A>();
    plant::FF16_Environment<A> e2 = ed.template rebind_from<A>();
    e2.r_init_interpolators(field_state());
    for (A* p : s2.ad_parameters()) t2.registerInput(*p);
    e2.for_each_active([&](A& x) { t2.registerInput(x); });
    A hh = h0, aa = sd.area_leaf(h0);
    t2.registerInput(hh); t2.registerInput(aa);
    t2.newRecording();
    const auto n0 = t2.getNumStatements();
    A o = F(s2, e2, hh, aa);
    const auto n1 = t2.getNumStatements();
    t2.registerOutput(o);
    xad::derivative(o) = 1.0;
    t2.computeAdjoints();
    ret = {xad::value(o), xad::derivative(hh), xad::derivative(aa),
           xad::derivative(s2.pars.a_p1), double(n1 - n0)};
    }
    tape.activate();
    return ret;
  };
  const std::vector<double> g_cur = grad([&](auto& st, auto& en, const A& hh, const A& aa) {
    return st.assimilation(en, hh, aa, A(1.0 / hh)); });
  const std::vector<double> g_fold = grad(folded_on);
  // Double central differences of the current path, area_leaf held.
  const double al0 = sd.area_leaf(h0), eps = 1e-6 * h0;
  const double fd_h = (sd.assimilation(ed, h0 + eps, al0, 1.0 / (h0 + eps)) -
                       sd.assimilation(ed, h0 - eps, al0, 1.0 / (h0 - eps))) / (2 * eps);
  plant::FF16_Strategy<double> sp = sd, sm = sd;
  const double ea1 = 1e-6 * sd.pars.a_p1;
  sp.pars.a_p1 += ea1; sm.pars.a_p1 -= ea1;
  const double fd_ap1 = (sp.assimilation(ed, h0, al0, 1.0 / h0) -
                         sm.assimilation(ed, h0, al0, 1.0 / h0)) / (2 * ea1);
  Tape& tape_ = tape; (void)tape_;
  auto stf0 = 0, stf1 = 0;
  const double dAdh2 = 0;
  A out2 = 0.0;
  double t_rec2 = 0;
  for (int r = 0; r < reps; ++r) {
    tape.resetTo(pos0);
    auto a = std::chrono::steady_clock::now();
    A o = folded(h, al);
    t_rec2 += std::chrono::duration<double>(std::chrono::steady_clock::now() - a).count();
  }
  return Rcpp::List::create(
      Rcpp::_["current"] = g_cur, Rcpp::_["fd_h_ap1"] = std::vector<double>{fd_h, fd_ap1}, Rcpp::_["folded"] = g_fold, Rcpp::_["folded_ns_record"] = 1e9 * t_rec2 / reps,
      Rcpp::_["value"] = xad::value(out), Rcpp::_["dA_dh"] = dAdh,
      Rcpp::_["stmts_area_leaf"] = (double)(st1 - st0),
      Rcpp::_["stmts_integral"] = (double)(st2 - st1 - 1),
      Rcpp::_["ops_integral"] = (double)(op2 - op0),
      Rcpp::_["ns_double"] = 1e9 * t_double,
      Rcpp::_["ns_record"] = 1e9 * t_rec / reps,
      Rcpp::_["ns_sweep"] = 1e9 * t_sweep / reps, Rcpp::_["sink"] = sink);
}
