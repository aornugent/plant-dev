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

// One rate evaluation, replayed piece by piece as Patch::set_ode_state and
// Patch::ode_rates run it, then a liveness pass from the rates back: a statement
// is live if its left-hand slot is read by a later live statement or is a rate.
// [[Rcpp::export]]
Rcpp::DataFrame live_regions(SEXP patch_sexp) {
  PatchD patch = Rcpp::as<PatchD>(patch_sexp);
  std::vector<double> y(patch.ode_size());
  patch.ode_state(y.begin());
  const double time = patch.ode_time();

  Tape tape;
  auto p = patch.template rebind_from<A>();
  for (A* q : p.ad_parameters()) tape.registerInput(*q);
  std::vector<A> ya(y.begin(), y.end());
  tape.registerInputs(ya);
  tape.newRecording();

  std::vector<std::string> names;
  std::vector<std::size_t> ends;
  auto mark = [&](const char* name) {
    names.push_back(name);
    ends.push_back(tape.getNumStatements());
  };
  const std::size_t start = tape.getNumStatements();

  // Patch::set_ode_state
  auto it = odelia::ode::set_ode_state(p.species.begin(), p.species.end(), ya.cbegin());
  it = p.environment.set_ode_state(it);
  p.environment.time = time;
  mark("load state");
  for (auto& s : p.species) s.set_new_node_birth_date(p.environment.time);
  // compute_environment_excl_capturing, with marks inside its reduction.
  p.competition_capture.resize(p.size());
  double read_below = 0.0;
  for (const auto& sp : p.species)
    read_below = std::max(read_below, odelia::util::to_passive(sp.r_new_node().height()));
  auto f = [&](const std::vector<A>& x, std::vector<A>& yk, std::vector<A>& mk) {
    mark("excl: knot heights");
    for (size_t k = 0; k < x.size(); ++k) { yk[k] = 0.0; mk[k] = 0.0; }
    for (size_t i = 0; i < p.size(); ++i) {
      p.species[i].field_splits(x, p.competition_capture[i]);
      mark("excl: field_splits");
      for (size_t k = 0; k < x.size() && plant::knot_built(x, k, read_below); ++k) {
        const auto& sum = p.competition_capture[i][k].sum;
        yk[k] += (sum.value / 2) / p.area;
        mk[k] += (sum.slope / 2) / p.area;
      }
      mark("excl: accumulate");
    }
  };
  p.environment.compute_environment(f, p.height_max(), read_below);
  mark("excl: extinction + spline");
  p.compute_boundary_nodes();
  mark("boundary node (in that field)");
  p.compute_environment_closing();
  mark("closing field");
  // Patch::ode_rates -> compute_rates
  const double pr = p.survival_weighting->pr_survival(time);
  for (auto& s : p.species) {
    for (auto& c : s.nodes) c.compute_rates(p.environment, pr);
    mark("node rates");
    const A br = s.strategy_ptr()->birth_rate_at(time);
    s.new_node.compute_initial_conditions(p.environment, pr, br);
    mark("boundary node again (closed field)");
  }
  std::vector<A> dydt(y.size());
  auto ot = odelia::ode::ode_rates(p.species.begin(), p.species.end(), dydt.begin());
  p.environment.ode_rates(ot);
  mark("write rates");

  Rcpp::Rcout << "recorded " << tape.getNumStatements() << "\n";
  // Liveness, backwards.
  std::vector<char> live_slot(tape.derivatives_.size() + tape.getNumVariables() + 1000000, 0);
  auto set_live = [&](unsigned s, char v) {
    if (s == A::INVALID_SLOT) return;
    if (s >= live_slot.size()) live_slot.resize(std::size_t(s) + 1, 0);
    live_slot[s] = v;
  };
  for (auto& d : dydt) if (d.getSlot() != A::INVALID_SLOT) set_live(d.getSlot(), 1);
  const std::size_t end = tape.getNumStatements();
  std::vector<char> live(end, 0);
  for (std::size_t i = end; i-- > start;) {
    const unsigned lhs = tape.statement_[i].second;
    if (lhs < live_slot.size() && live_slot[lhs]) {
      live[i] = 1;
      set_live(lhs, 0);  // defined here: an earlier use is an earlier definition
      const std::size_t b = i == 0 ? 0 : tape.statement_[i - 1].first, e = tape.statement_[i].first;
      for (std::size_t o = b; o < e; ++o) set_live(tape.operations_[o].second, 1);
    }
  }
  Rcpp::Rcout << "liveness done\n";
  // Forward taint from the state: a statement none of whose operands descends
  // from a state input depends on the parameters alone.
  std::vector<char> state_slot(live_slot.size(), 0);
  auto set_state = [&](unsigned sl, char v) {
    if (sl == A::INVALID_SLOT) return;
    if (sl >= state_slot.size()) state_slot.resize(std::size_t(sl) + 1, 0);
    state_slot[sl] = v;
  };
  for (auto& v : ya) set_state(v.getSlot(), 1);
  std::vector<char> param_only(end, 0);
  for (std::size_t i = start; i < end; ++i) {
    const std::size_t b = i == 0 ? 0 : tape.statement_[i - 1].first, e = tape.statement_[i].first;
    char t = 0;
    for (std::size_t o = b; o < e; ++o) {
      const unsigned sl = tape.operations_[o].second;
      if (sl < state_slot.size() && state_slot[sl]) t = 1;
    }
    set_state(tape.statement_[i].second, t);
    param_only[i] = (t == 0 && e > b);
  }
  Rcpp::Rcout << "taint done\n";
  std::vector<std::string> region;
  std::vector<double> total, dead, ponly;
  std::size_t from = start;
  for (std::size_t r = 0; r < names.size(); ++r) {
    double t = 0, d = 0, q = 0;
    for (std::size_t i = from; i < ends[r]; ++i) { ++t; if (!live[i]) ++d; else if (param_only[i]) ++q; }
    region.push_back(names[r]); total.push_back(t); dead.push_back(d); ponly.push_back(q);
    from = ends[r];
  }
  return Rcpp::DataFrame::create(Rcpp::_["region"] = region, Rcpp::_["statements"] = total,
                                 Rcpp::_["dead"] = dead, Rcpp::_["live_parameter_only"] = ponly);
}
