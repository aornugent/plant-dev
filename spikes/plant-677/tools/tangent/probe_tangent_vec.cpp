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

using SCMD = plant::SCM<plant::FF16_Strategy<double>, plant::FF16_Environment<double>>;

template <std::size_t N, class D> double& lane(D& d, std::size_t j) {
  if constexpr (N == 1) { return d; } else { return d[j]; }
}
template <std::size_t N, class D> double lane_of(const D& d, std::size_t j) {
  if constexpr (N == 1) { return d; } else { return d[j]; }
}

// census_trait_tangent at N directions in one pass: lane j seeds trait cols[j].
template <std::size_t N>
Rcpp::NumericMatrix tangent_lanes(SCMD& scm, const std::vector<int>& cols) {
  using V = xad::FReal<double, N>;
  const auto rec = scm.store_trajectory();
  auto& live = scm.solver.get_system_ref();
  odelia::ode::be_at_step(live, rec, 0);
  auto active = live.template rebind_from<V>();
  std::vector<V*> pars = active.ad_parameters();
  for (std::size_t j = 0; j < N && j < cols.size(); ++j) {
    lane<N>(xad::derivative(*pars[cols[j]]), j) = 1.0;
  }
  std::vector<V> x0(rec[0].state.size());
  for (std::size_t i = 0; i < x0.size(); ++i) x0[i] = rec[0].state[i];
  active.set_ode_state(x0.begin(), rec[0].time);
  odelia::ode::Solver<decltype(active)> forward(active, plant::make_ode_control(scm.control));
  forward.set_collect(false);
  forward.set_state_from_system();
  forward.advance_recorded(odelia::ode::program_from(
      rec, 0, {forward.time(), std::numeric_limits<double>::quiet_NaN()}));
  odelia::ode::be_at_step(scm.solver.get_system_ref(), rec, rec.size() - 1);
  const auto& reached = forward.get_system_ref();
  const auto metrics = scm.stand_metrics();
  Rcpp::NumericMatrix out(metrics.size(), N);
  for (std::size_t m = 0; m < metrics.size(); ++m) {
    const V v = scm.metric_value(reached, metrics[m]);
    for (std::size_t j = 0; j < N; ++j) out(m, j) = lane_of<N>(xad::derivative(v), j);
  }
  return out;
}

// [[Rcpp::export]]
Rcpp::NumericMatrix tangent_lanes_ff16(plant::RcppR6::RcppR6<SCMD> obj_, std::vector<int> cols, int width) {
  switch (width) {
    case 1: return tangent_lanes<1>(*obj_, cols);
    case 2: return tangent_lanes<2>(*obj_, cols);
    case 4: return tangent_lanes<4>(*obj_, cols);
    case 8: return tangent_lanes<8>(*obj_, cols);
    case 16: return tangent_lanes<16>(*obj_, cols);
    case 32: return tangent_lanes<32>(*obj_, cols);
  }
  Rcpp::stop("width");
}
