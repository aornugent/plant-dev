// [[Rcpp::plugins(cpp20)]]
// [[Rcpp::depends(plant, odelia, phylloptim, BH)]]
#include <Rcpp.h>
#include <plant.h>
#include <chrono>
#include <thread>

using A = xad::AReal<double>;
using Tape = xad::Tape<double>;
using PatchD = plant::Patch<plant::FF16_Strategy<double>, plant::FF16_Environment<double>>;
using clk = std::chrono::steady_clock;

// Record `k` step tapes (six rate evaluations each) of one patch state on this
// thread's own tape and active patch.
static void record_steps(const PatchD& patch, const std::vector<double>& y,
                         double time, int k, double& statements) {
  Tape tape;
  auto active = patch.template rebind_from<A>();
  std::vector<A*> pars = active.ad_parameters();
  std::vector<std::vector<A>> out(6, std::vector<A>(y.size()));
  for (int r = 0; r < k; ++r) {
    active.for_each_active([](A& x) { x = A(xad::value(x)); });
    for (auto& row : out) for (auto& o : row) o = A(xad::value(o));
    tape.clearAll();
    for (A* p : pars) tape.registerInput(*p);
    std::vector<A> ya(y.begin(), y.end());
    tape.registerInputs(ya);
    tape.newRecording();
    for (int s = 0; s < 6; ++s) {
      active.set_ode_state(ya.begin(), time);
      active.compute_boundary_nodes();
      active.ode_rates(out[s].begin());
    }
    statements = double(tape.getNumStatements());
  }
  active.for_each_active([](A& x) { x = A(xad::value(x)); });
  for (auto& row : out) for (auto& o : row) o = A(xad::value(o));
}

// [[Rcpp::export]]
Rcpp::NumericVector probe_parallel(SEXP patch_sexp, int k, int threads) {
  PatchD patch = Rcpp::as<PatchD>(patch_sexp);
  std::vector<double> y(patch.ode_size());
  patch.ode_state(y.begin());
  const double time = patch.ode_time();
  double st = 0;
  auto a = clk::now();
  record_steps(patch, y, time, k * threads, st);
  auto b = clk::now();
  std::vector<std::thread> pool;
  std::vector<double> sts(threads);
  for (int t = 0; t < threads; ++t)
    pool.emplace_back([&, t] { record_steps(patch, y, time, k, sts[t]); });
  for (auto& th : pool) th.join();
  auto c = clk::now();
  return Rcpp::NumericVector::create(
      Rcpp::_["serial_s"] = std::chrono::duration<double>(b - a).count(),
      Rcpp::_["parallel_s"] = std::chrono::duration<double>(c - b).count(),
      Rcpp::_["statements"] = st, Rcpp::_["statements_thread0"] = sts[0]);
}
