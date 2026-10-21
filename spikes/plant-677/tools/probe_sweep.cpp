// [[Rcpp::plugins(cpp20)]]
// [[Rcpp::depends(plant, odelia, phylloptim, BH)]]
#include <Rcpp.h>
#include "tape_local.inc"  // XAD's tape runtime at widths 1 and 5, local to this object
#include <plant.h>
#include <chrono>
#include <random>

using PatchD = plant::Patch<plant::FF16_Strategy<double>, plant::FF16_Environment<double>>;
using clk = std::chrono::steady_clock;

static double secs(clk::time_point a, clk::time_point b) {
  return std::chrono::duration<double>(b - a).count();
}

// Record `stages` rate evaluations of one patch state onto one tape (a step's
// worth), then sweep K seeds: K sweeps at width 1, or one at width K.
template <std::size_t N, bool zero_inputs_only = false>
std::vector<double> run(const PatchD& patch, const std::vector<double>& y, double time,
                        int stages, const std::vector<std::vector<double>>& seeds,
                        std::vector<std::vector<double>>& adj, double& t_rec,
                        double& t_sweep, double& stmts) {
  using A = xad::AReal<double, N>;
  using Tape = xad::Tape<double, N>;
  const std::size_t K = seeds.size();
  Tape tape;
  auto active = patch.template rebind_from<A>();
  std::vector<A*> pars = active.ad_parameters();
  for (A* p : pars) tape.registerInput(*p);
  std::vector<A> ya(y.begin(), y.end());
  tape.registerInputs(ya);
  tape.newRecording();
  std::vector<std::vector<A>> out(stages, std::vector<A>(y.size()));
  auto a = clk::now();
  for (int s = 0; s < stages; ++s) {
    active.set_ode_state(ya.begin(), time);
    active.compute_boundary_nodes();
    active.ode_rates(out[s].begin());
  }
  auto b = clk::now();
  t_rec = secs(a, b);
  stmts = double(tape.getNumStatements());
  adj.assign(K, std::vector<double>(y.size() + pars.size(), 0.0));
  auto c = clk::now();
  if constexpr (N == 1) {
    for (std::size_t m = 0; m < K; ++m) {
      if (!zero_inputs_only || m == 0) {
        tape.clearDerivatives();
      } else {
        // A full sweep zeroes every left-hand adjoint; only the inputs hold one.
        for (auto& v : ya) xad::derivative(v) = 0.0;
        for (A* p : pars) xad::derivative(*p) = 0.0;
      }
      std::size_t i = 0;
      for (auto& row : out) for (auto& o : row) xad::derivative(o) = seeds[m][i++];
      tape.computeAdjoints();
      for (std::size_t j = 0; j < y.size(); ++j) adj[m][j] = xad::derivative(ya[j]);
      for (std::size_t j = 0; j < pars.size(); ++j) adj[m][y.size() + j] = xad::derivative(*pars[j]);
    }
  } else {
    tape.clearDerivatives();
    std::size_t i = 0;
    for (auto& row : out)
      for (auto& o : row) {
        for (std::size_t m = 0; m < K; ++m) xad::derivative(o)[m] = seeds[m][i];
        ++i;
      }
    tape.computeAdjoints();
    for (std::size_t m = 0; m < K; ++m) {
      for (std::size_t j = 0; j < y.size(); ++j) adj[m][j] = xad::derivative(ya[j])[m];
      for (std::size_t j = 0; j < pars.size(); ++j) adj[m][y.size() + j] = xad::derivative(*pars[j])[m];
    }
  }
  t_sweep = secs(c, clk::now());
  return {};
}

// [[Rcpp::export]]
Rcpp::DataFrame probe_vec(SEXP patch_sexp, int stages, int reps) {
  PatchD patch = Rcpp::as<PatchD>(patch_sexp);
  std::vector<double> y(patch.ode_size());
  patch.ode_state(y.begin());
  const double time = patch.ode_time();
  const std::size_t K = 5, n_out = std::size_t(stages) * y.size();
  std::mt19937 gen(1);
  std::normal_distribution<double> nd;
  std::vector<std::vector<double>> seeds(K, std::vector<double>(n_out));
  for (auto& s : seeds) for (auto& v : s) v = nd(gen);

  std::vector<std::string> arm;
  std::vector<double> rec, sweep, st, worst;
  for (int r = 0; r < reps; ++r) {
    std::vector<std::vector<double>> a1, a2;
    double r1, s1, n1, r2, s2, n2;
    run<1, false>(patch, y, time, stages, seeds, a1, r1, s1, n1);
    run<1, true>(patch, y, time, stages, seeds, a2, r2, s2, n2);
    double w = 0;
    for (std::size_t m = 0; m < K; ++m)
      for (std::size_t j = 0; j < a1[m].size(); ++j)
        w = std::max(w, std::abs(a1[m][j] - a2[m][j]) / std::max(1e-300, std::abs(a1[m][j])));
    arm.push_back("clear each seed"); rec.push_back(r1); sweep.push_back(s1); st.push_back(n1); worst.push_back(0);
    arm.push_back("zero inputs only"); rec.push_back(r2); sweep.push_back(s2); st.push_back(n2); worst.push_back(w);
  }
  return Rcpp::DataFrame::create(Rcpp::_["arm"] = arm, Rcpp::_["record_s"] = rec,
                                 Rcpp::_["sweep_s"] = sweep, Rcpp::_["statements"] = st,
                                 Rcpp::_["worst_rel_diff"] = worst);
}
