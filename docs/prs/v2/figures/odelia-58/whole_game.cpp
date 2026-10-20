// The Chooser System of odelia tests/standalone/r_free.cpp: y' = r y s, where
// s is a choice each stage makes from its own state (1 below y = 100, 0.5
// above) and keeps in the row.
#include <cmath>
#include <cstdio>
#include <vector>
#include <odelia/ode_solver.hpp>

struct solved_choice { double s = 0.0; bool kept = false; double t = 0.0; };

template <typename T = double>
struct Chooser {
  using value_type = T;
  using solved_values = solved_choice;
  template <typename> friend struct Chooser;
  T r;
  std::vector<T> y, dydt;
  double time = 0.0;
  solved_choice* into = nullptr;
  const solved_choice* from = nullptr;
  explicit Chooser(T r_ = T(1.0)) : r(r_) { reset(); }
  template <class S> Chooser<S> rebind_from() const {
    Chooser<S> out(S(xad::value(r)));
    out.y.assign(1, S(xad::value(y[0])));
    out.time = time;
    out.compute_rates();
    return out;
  }
  size_t ode_size() const { return 1; }
  double ode_time() const { return time; }
  template <class It> It set_ode_state(It it, double t) {
    y[0] = *it++; time = t; compute_rates(); return it;
  }
  void set_recorded_state(const std::vector<T>& s, double t) { set_ode_state(s.begin(), t); }
  void store_solved(solved_choice& s) { into = &s; from = nullptr; }
  void load_solved(const solved_choice& s) { from = s.kept ? &s : nullptr; into = nullptr; }
  void end_solved() { into = nullptr; from = nullptr; }
  void compute_rates() {
    const double s = from != nullptr ? from->s : (xad::value(y[0]) < 100.0 ? 1.0 : 0.5);
    if (into != nullptr) { into->s = s; into->kept = true; into->t = time; }
    dydt.assign(1, r * y[0] * s);
  }
  template <class It> It ode_state(It it) const { *it++ = y[0]; return it; }
  template <class It> It ode_rates(It it) const { *it++ = dydt[0]; return it; }
  void reset() { y.assign(1, T(1.0)); time = 0.0; compute_rates(); }
  std::vector<T*> ad_parameters() { return {&r}; }
  template <class F> void for_each_active(F&& f) { f(r); for (T& c : y) f(c); for (T& c : dydt) f(c); }
};

using odelia::ode::OdeControl;
using odelia::ode::Solver;

template <class Rec> int count_halves(const Rec& rec) {
  int n = 0;
  for (size_t k = 1; k < rec.size(); ++k)
    for (const solved_choice& c : rec[k].solved) n += c.s == 0.5;
  return n;
}

int main() {
  // A run at r = 2 stays below the threshold, so every stage chose s = 1.
  Solver<Chooser<>> run(Chooser<>(2.0), OdeControl{});
  run.set_keep_states(true);
  run.reset();
  run.advance_adaptive(std::vector<double>{0.0, 1.0});
  const auto rec = run.recording();

  // A replay of its steps at r = 5 that reuses every recorded choice.
  Solver<Chooser<>> reuses(Chooser<>(5.0), OdeControl{});
  reuses.set_keep_states(true);
  reuses.reset();
  reuses.advance_recorded(rec);

  // The same replay, storing its own choices in a copy of each step's values.
  Solver<Chooser<>> stores(Chooser<>(5.0), OdeControl{});
  stores.set_keep_states(true);
  stores.reset();
  stores.advance_recorded(rec, true);

  // A fresh run at r = 5 on the same steps, with no recorded values at all.
  Solver<Chooser<>> fresh(Chooser<>(5.0), OdeControl{});
  fresh.advance_recorded(run.schedule());

  std::printf("y(1): reuses %.12g  stores %.12g  fresh run on the same steps %.12g\n",
              reuses.state()[0], stores.state()[0], fresh.state()[0]);
  std::printf("choices of s = 0.5: recorded %d  reuses %d  stores %d of %zu\n",
              count_halves(rec), count_halves(reuses.recording()),
              count_halves(stores.recording()), 6 * (rec.size() - 1));

  // d y(1) / d r from a sweep of each pass's own recording, and a central
  // difference of that pass.
  auto sweep = [](auto& solver) {
    auto lambda = odelia::ode::adjoint_rows::one_row({1.0});
    odelia::ode::adjoint_rows dp(1, 1);
    solver.solve_adjoint(lambda, dp);
    return dp[0][0];
  };
  auto pass_at = [&](double r, bool store) {
    Solver<Chooser<>> s(Chooser<>(r), OdeControl{});
    s.advance_recorded(rec, store);
    return s.state()[0];
  };
  const double h = 1e-6;
  std::printf("dy(1)/dr from the sweep: reuses %.8g  stores %.8g\n",
              sweep(reuses), sweep(stores));
  std::printf("dy(1)/dr from central differences: reuses %.8g  stores %.8g\n",
              (pass_at(5 + h, false) - pass_at(5 - h, false)) / (2 * h),
              (pass_at(5 + h, true) - pass_at(5 - h, true)) / (2 * h));
}
