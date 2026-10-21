// [[Rcpp::plugins(cpp20)]]
// [[Rcpp::depends(plant, odelia, phylloptim, BH)]]
#include <Rcpp.h>
#include <sstream>
#include <map>
#include <set>
#include <array>
#include <memory>
#include <functional>
#include <span>
#include <optional>
#include <variant>
#include <numeric>
#include <algorithm>
#include <chrono>
#include <random>
#include <boost/math/tools/roots.hpp>
#define private public
#define protected public
#include <XAD/XAD.hpp>
#include <plant.h>
#undef private
#undef protected

using A = xad::AReal<double>;
using Tape = xad::Tape<double>;
using PatchD = plant::Patch<plant::FF16_Strategy<double>, plant::FF16_Environment<double>>;
using clk = std::chrono::steady_clock;

// One backward walk over the recorded statements carrying M adjoints per slot,
// lane-major within a slot: adj[slot * M + m].
template <int M>
void sweep_lanes(const Tape& tape, std::vector<double>& adj, std::size_t end) {
  for (std::size_t i = end; i-- > 1;) {
    const auto st = tape.statement_[i];
    if (st.second == A::INVALID_SLOT) continue;
    if ((std::size_t(st.second) + 1) * M > adj.size()) Rcpp::stop("lhs oob " + std::to_string(st.second) + " at " + std::to_string(i));
    double* lhs = adj.data() + std::size_t(st.second) * M;
    double a[M];
    bool any = false;
    for (int m = 0; m < M; ++m) { a[m] = lhs[m]; lhs[m] = 0.0; any |= a[m] != 0.0; }
    if (!any) continue;
    tape.operations_.for_each(tape.statement_[i - 1].first, st.first,
                              [&](const double& mul, unsigned slot) {
      if ((std::size_t(slot) + 1) * M > adj.size()) Rcpp::stop("op oob " + std::to_string(slot) + " at " + std::to_string(i));
      double* d = adj.data() + std::size_t(slot) * M;
      for (int m = 0; m < M; ++m) d[m] += mul * a[m];
    });
  }
}

// [[Rcpp::export]]
Rcpp::DataFrame probe_lanes(SEXP patch_sexp, int stages, int reps) {
  PatchD patch = Rcpp::as<PatchD>(patch_sexp);
  std::vector<double> y(patch.ode_size());
  patch.ode_state(y.begin());
  const double time = patch.ode_time();
  constexpr std::size_t K = 5;

  Tape tape;
  auto active = patch.template rebind_from<A>();
  std::vector<A*> pars = active.ad_parameters();
  for (A* p : pars) tape.registerInput(*p);
  std::vector<A> ya(y.begin(), y.end());
  tape.registerInputs(ya);
  tape.newRecording();
  std::vector<std::vector<A>> out(stages, std::vector<A>(y.size()));
  for (int s = 0; s < stages; ++s) {
    active.set_ode_state(ya.begin(), time);
    active.compute_boundary_nodes();
    active.ode_rates(out[s].begin());
  }
  const std::size_t n_out = std::size_t(stages) * y.size();
  std::mt19937 gen(1);
  std::normal_distribution<double> nd;
  std::vector<std::vector<double>> seeds(K, std::vector<double>(n_out));
  for (auto& s : seeds) for (auto& v : s) v = nd(gen);
  const std::size_t end = tape.getNumStatements();
  std::size_t n_slots = 0;
  for (std::size_t i = 0; i < tape.statement_.size(); ++i) if (tape.statement_[i].second != A::INVALID_SLOT) n_slots = std::max<std::size_t>(n_slots, std::size_t(tape.statement_[i].second) + 1); else Rcpp::Rcout << "invalid lhs at statement " << i << " ops " << (i ? tape.statement_[i].first - tape.statement_[i-1].first : 0) << "\n";
  tape.operations_.for_each(0, tape.operations_.size(), [&](const double&, unsigned sl) { n_slots = std::max<std::size_t>(n_slots, sl + 1); });

  std::size_t invalid = 0;
  for (auto& row : out) for (auto& o : row) invalid += o.getSlot() == A::INVALID_SLOT;
  Rcpp::Rcout << "passive outputs " << invalid << " of " << n_out << "\n";
  std::vector<std::string> arm; std::vector<double> secs, worst;
  std::vector<std::vector<double>> ref(K);
  for (int r = 0; r < reps; ++r) {
    // K scalar sweeps, as odelia runs them.
    auto a0 = clk::now();
    for (std::size_t m = 0; m < K; ++m) {
      tape.clearDerivatives();
      std::size_t i = 0;
      for (auto& row : out) for (auto& o : row) xad::derivative(o) = seeds[m][i++];
      tape.computeAdjoints();
      ref[m].clear();
      for (auto& v : ya) ref[m].push_back(xad::derivative(v));
      for (A* p : pars) ref[m].push_back(xad::derivative(*p));
    }
    auto a1 = clk::now();
    // One walk, K lanes (and K padded to 8).
    auto lane = [&](auto Mc, const char* name) {
      constexpr int M = decltype(Mc)::value;
      auto b0 = clk::now();
      std::vector<double> adj(std::max<std::size_t>(n_slots, tape.derivatives_.size()) * M, 0.0);
      std::size_t i = 0;
      for (auto& row : out) for (auto& o : row) { if (o.getSlot() != A::INVALID_SLOT && (std::size_t(o.getSlot()) + 1) * M > adj.size()) Rcpp::stop("seed oob " + std::to_string(o.getSlot()) + " n " + std::to_string(adj.size()));
        if (o.getSlot() != A::INVALID_SLOT) for (std::size_t m = 0; m < std::min<std::size_t>(K, M); ++m) adj[std::size_t(o.getSlot()) * M + m] = seeds[m][i]; ++i; }
      sweep_lanes<M>(tape, adj, tape.statement_.size());
      auto b1 = clk::now();
      double w = 0;
      for (std::size_t m = 0; m < std::min<std::size_t>(K, M); ++m) {
        std::size_t j = 0;
        for (auto& v : ya) { const double x = adj[std::size_t(v.getSlot()) * M + m]; const double e = std::abs(x - ref[m][j]) / std::max(1e-300, std::abs(ref[m][j])); if (false && r == 0 && M == 5 && m == 0) Rcpp::Rcout << "state " << j << " lane " << x << " scalar " << ref[m][j] << "\n"; w = std::max(w, e); ++j; }
        for (A* p : pars) { const double x = adj[std::size_t(p->getSlot()) * M + m]; w = std::max(w, std::abs(x - ref[m][j]) / std::max(1e-300, std::abs(ref[m][j]))); ++j; }
      }
      arm.push_back(name); secs.push_back(std::chrono::duration<double>(b1 - b0).count()); worst.push_back(w);
    };
    arm.push_back("5 scalar sweeps"); secs.push_back(std::chrono::duration<double>(a1 - a0).count()); worst.push_back(0);
    lane(std::integral_constant<int, 1>{}, "one walk, 1 lane (seed 0 only checked)");
    lane(std::integral_constant<int, 5>{}, "one walk, 5 lanes");
    lane(std::integral_constant<int, 8>{}, "one walk, 8 lanes (5 used)");
  }
  Rcpp::Rcout << "statements " << end << " operations " << tape.operations_.size() << " slots " << tape.derivatives_.size() << "\n";
  return Rcpp::DataFrame::create(Rcpp::_["arm"] = arm, Rcpp::_["seconds"] = secs, Rcpp::_["worst_rel_diff"] = worst);
}
