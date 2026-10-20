# Compiles G_derivative() and collar_derivative(): the leaf's derivative path called
# through Rcpp against the phylloptim installed in `ph_lib`, with the odelia
# headers in `od_lib`.
compile_leaf <- function(ph_lib, od_lib) {
  inc <- c(file.path(ph_lib, "phylloptim", "include"), file.path(od_lib, "odelia", "include"),
           system.file("include", package = "BH"))
  Sys.setenv(PKG_CPPFLAGS = paste(paste0("-isystem", shQuote(inc)), collapse = " "),
             PKG_CXXFLAGS = "-DXAD_NO_THREADLOCAL -DXAD_USE_STRONG_INLINE -O2")
  Rcpp::sourceCpp(env = globalenv(), code = '
  // [[Rcpp::plugins(cpp20)]]
  #include <Rcpp.h>
  #include <phylloptim.hpp>
  #include <odelia/tangent.hpp>
  #include <cmath>
  #include <string>
  #include <vector>

  using AD = xad::fwd<double>::active_type;
  using T = odelia::ode::tangent_scalar<double>;

  phylloptim::MultiLayerRoots roots_at(double P50, double c, double resolution) {
    phylloptim::MultiLayerRoots r;
    r.root_P50 = P50;
    r.root_c = c;
    r.root_b = phylloptim::weibull_b_from_P50(P50, c);
    r.setup_vulnerability(resolution);
    return r;
  }

  // G(psi) as the root table returns it, its derivative in root_P50 on the derivative path,
  // and a central difference of the table read in root_P50.
  // [[Rcpp::export]]
  Rcpp::DataFrame G_derivative(std::vector<double> psi, double P50, double c,
                         double resolution, double h) {
    const phylloptim::MultiLayerRoots r = roots_at(P50, c, resolution),
      up = roots_at(P50 + h, c, resolution), down = roots_at(P50 - h, c, resolution);
    std::vector<double> value(psi.size()), deriv(psi.size()), fd(psi.size());
    std::vector<std::string> refused(psi.size());
    for (size_t i = 0; i < psi.size(); ++i) {
      value[i] = r.root_vuln_integral_at(psi[i]);
      fd[i] = (up.root_vuln_integral_at(psi[i]) - down.root_vuln_integral_at(psi[i])) / (2 * h);
      AD aP50 = P50, ac = c;
      xad::derivative(aP50) = 1.0;
      try {
        const AD G = phylloptim::closed_form_integral<AD>(
          value[i], r.root_vuln_integral_deriv_at(psi[i]), AD(psi[i]), aP50, ac);
        deriv[i] = xad::derivative(G);
      } catch (const std::exception& e) {
        deriv[i] = NA_REAL;
        refused[i] = e.what();
      }
    }
    return Rcpp::DataFrame::create(Rcpp::_["psi"] = psi, Rcpp::_["G"] = value,
      Rcpp::_["deriv"] = deriv, Rcpp::_["fd"] = fd, Rcpp::_["refused"] = refused,
      Rcpp::_["dry_end"] = phylloptim::vulnerability_psi_max(r.root_b, c),
      Rcpp::_["G_inf"] = phylloptim::cumulative_vulnerability_integral_limit(r.root_b, c));
  }

  struct Fixture {
    double stem_P50, root_P50, GSS_tol_abs, resolution;
  };

  // One layer 1 m deep, the drivers of phylloptim tests/cpp/test_leaf.cpp.
  phylloptim::Leaf leaf_at(const Fixture& f, double psi_soil, bool solve) {
    const double theta = 0.000157, K_s = 1.0, h = 5.0, area_leaf = 0.05;
    const std::vector<double> ps{psi_soil}, depth{1.0}, root{1.0 / area_leaf};
    phylloptim::Leaf l;
    l.GSS_tol_abs = f.GSS_tol_abs;
    l.setup_transpiration(f.resolution);
    l.setup_root_vulnerability(f.resolution);
    l.set_traits(96.0, 2.680147, f.stem_P50, 2.680147, f.root_P50, 1.5, 157.44, 0.30,
                 0.7, 0.99, 7.5, 1.44, 1.0, 0.6, 0.0);
    l.set_physiology(phylloptim::root_network_from_carbon(
                       root, phylloptim::layer_thicknesses(depth), 3.4e2, 9.4e3),
                     900.0, ps, depth, K_s * theta / h, 2.0, 40.0, 25.0, 21.0, 101.3);
    if (solve) l.find_root_collar_psi();
    return l;
  }

  // Across psi_soil: the feasible interval\'s two bounds as the solve brackets
  // them, the kind, the collar, its derivative in psi_soil from collar_at on the tangent
  // scalar, and a central difference of the solved collar.
  // [[Rcpp::export]]
  Rcpp::DataFrame collar_derivative(std::vector<double> psi_soil, double stem_P50,
                              double root_P50, double GSS_tol_abs,
                              double resolution, double h) {
    constexpr auto K = phylloptim::Leaf::CostCurve::TF24;
    const Fixture f{stem_P50, root_P50, GSS_tol_abs, resolution};
    const size_t n = psi_soil.size();
    std::vector<double> wet(n), dry(n), collar(n), deriv(n), fd(n), psi_crit(n), root_psi_crit(n);
    std::vector<std::string> kind(n), refused(n);
    for (size_t i = 0; i < n; ++i) {
      phylloptim::Leaf b = leaf_at(f, psi_soil[i], false);
      double a = NA_REAL, z = NA_REAL;
      try { b.template prepare_collar_solve<K>(a, z); } catch (const std::exception&) {}
      wet[i] = a; dry[i] = z;
      psi_crit[i] = b.psi_crit; root_psi_crit[i] = b.roots_.root_psi_crit;
      phylloptim::Leaf l = leaf_at(f, psi_soil[i], true);
      kind[i] = phylloptim::Leaf::operating_point_kind_name(l.operating_point_kind());
      collar[i] = l.opt_root_psi_;
      fd[i] = (leaf_at(f, psi_soil[i] + h, true).opt_root_psi_ -
               leaf_at(f, psi_soil[i] - h, true).opt_root_psi_) / (2 * h);
      try {
        phylloptim::leaf_pars<T> pars;
        const phylloptim::leaf_pars<double> seated = l.passive_pars();
        for (size_t j = 0; j < pars.size(); ++j) pars[j] = T(seated[j]);
        std::vector<T> soil{T(l.roots_.psi_soil_[0])},
          r_h{T(l.roots_.network_.r_R_H_min[0])}, r_v{T(l.roots_.network_.r_R_V_sum[0])};
        odelia::ode::seed_direction(soil[0], 1.0);
        const phylloptim::SupplyAt<T> supply{soil, r_h, r_v, pars[phylloptim::par_root_P50],
                                             pars[phylloptim::par_root_c]};
        const auto draw = l.supply_draw_at<T>(T(l.opt_root_psi_), supply);
        deriv[i] = odelia::ode::derivative_along(l.collar_at<K, T>(draw, pars));
      } catch (const std::exception& e) {
        deriv[i] = NA_REAL;
        refused[i] = e.what();
      }
    }
    return Rcpp::DataFrame::create(Rcpp::_["psi_soil"] = psi_soil, Rcpp::_["wet"] = wet,
      Rcpp::_["dry"] = dry, Rcpp::_["kind"] = kind, Rcpp::_["collar"] = collar,
      Rcpp::_["deriv"] = deriv, Rcpp::_["fd"] = fd, Rcpp::_["refused"] = refused,
      Rcpp::_["psi_crit"] = psi_crit, Rcpp::_["root_psi_crit"] = root_psi_crit);
  }
  ', verbose = FALSE)
}
