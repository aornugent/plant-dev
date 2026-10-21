// [[Rcpp::plugins(cpp20)]]
// [[Rcpp::depends(plant, odelia, phylloptim, BH)]]
#include <plant.h>

using SCMD = plant::SCM<plant::FF16_Strategy<double>, plant::FF16_Environment<double>>;

// One forward tangent of the recorded run along `direction`: a tangent per metric.
// [[Rcpp::export]]
Rcpp::List tangent_ff16(plant::RcppR6::RcppR6<SCMD> obj_, std::vector<double> direction) {
  std::vector<double> value;
  const std::vector<double> t = obj_->census_trait_tangent(direction, value);
  return Rcpp::List::create(Rcpp::_["value"] = value, Rcpp::_["tangent"] = t);
}
