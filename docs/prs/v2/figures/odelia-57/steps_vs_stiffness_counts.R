# Accepted steps and rate evaluations on the toy of odelia's test-substeps.R
# (store as at a956c01, which still carries substep_below) to t = 2, for one
# arm, over K in 10^seq(1, 5, 0.5) and tol in 10^seq(-3, -10, -0.5), against
# plain Cash-Karp at 1e-12. Run under the odelia the arm needs:
#   R_LIBS=<odelia a956c01 build> Rscript steps_vs_stiffness_counts.R <odelia checkout> plain   -1  out.csv
#   R_LIBS=<odelia a956c01 build> Rscript steps_vs_stiffness_counts.R <odelia checkout> weak    0.1 out.csv
#   R_LIBS=<odelia d663a2b build> Rscript steps_vs_stiffness_counts.R <odelia checkout> C       0   out.csv
# The weak arm is the trigger of a956c01 (uptake under a tenth of the water
# moving through the store); C is d663a2b's, which ignores substep_below.
args <- commandArgs(TRUE)
od <- args[[1]]; arm <- args[[2]]; share <- as.numeric(args[[3]]); out <- args[[4]]
library(odelia)
testthat::source_test_helpers(file.path(od, "tests/testthat"), env = globalenv())
toy <- parse(text = system2("git", c("-C", od, "show", "a956c01:tests/testthat/test-substeps.R"),
                            stdout = TRUE))
for (e in toy[1:4]) eval(e)
counted <- store_system
counted <- sub("void compute_rates() {", "void compute_rates() { ++n_full;", counted, fixed = TRUE)
counted <- sub("      store_rates(t, w, out);\n      out[0] -= u[0];",
               "      ++n_sub;\n      store_rates(t, w, out);\n      out[0] -= u[0];", counted, fixed = TRUE)
stopifnot(grepl("++n_full", counted, fixed = TRUE), grepl("++n_sub", counted, fixed = TRUE))
ensure_ode_interface_loaded()
withr::local_envvar(PKG_CPPFLAGS = odelia_cppflags(odelia_include_dir()),
  PKG_LIBS = shQuote(normalizePath(.odelia_test_cache$odelia_so, mustWork = TRUE)))
Rcpp::sourceCpp(code = paste0('
  // [[Rcpp::plugins(cpp20)]]
  #include <Rcpp.h>
  #include <odelia/drivers.hpp>
  #include <odelia/ode_solver.hpp>
  static long n_full = 0, n_sub = 0;
  ', counted, '
  using namespace odelia;
  template <class Sys>
  Rcpp::List go(Sys sys, double tol, double t_end, std::vector<double> y0) {
    n_full = 0; n_sub = 0;
    ode::OdeControl ctl;
    ctl.set_tol_abs(tol); ctl.set_tol_rel(tol); ctl.set_controller(ode::Controller::gsl);
    ode::Solver<Sys> s(sys, ctl);
    s.set_state(y0, 0.0);
    s.advance_adaptive({0.0, t_end});
    auto prog = s.schedule();
    int substepped = 0;
    for (size_t k = 1; k < prog.size(); ++k) substepped += prog[k].subsystem.has_value();
    return Rcpp::List::create(Rcpp::_["y"] = s.state(), Rcpp::_["steps"] = (int) prog.size() - 1,
      Rcpp::_["substepped"] = substepped, Rcpp::_["full"] = (double) n_full,
      Rcpp::_["sub"] = (double) n_sub);
  }
  // [[Rcpp::export]]
  Rcpp::List run(double share, double tol, double t_end, std::vector<double> p,
                 std::vector<double> y0) {
    if (share < 0) return go(Store<double, false>(p[0], p[1], p[2], p[3], p[4]), tol, t_end, y0);
    Store<double, true> a(p[0], p[1], p[2], p[3], p[4]);
    a.substep_below = share;
    return go(a, tol, t_end, y0);
  }
'), verbose = FALSE)
rows <- list()
for (K in 10^seq(1, 5, by = 0.5)) {
  p <- store_pars; p[3] <- K
  ref <- run(-1, 1e-12, 2, p, store_y)$y
  for (tol in 10^seq(-3, -10, by = -0.5)) {
    r <- run(share, tol, 2, p, store_y)
    rows[[length(rows) + 1]] <- data.frame(K = K, arm = arm, tol = tol,
      error = max(abs(r$y - ref)), rel_error = max(abs(r$y - ref) / (1 + abs(ref))),
      steps = r$steps, substepped = r$substepped, full = r$full, sub = r$sub)
  }
}
write.table(do.call(rbind, rows), out, sep = ",", row.names = FALSE,
            append = file.exists(out), col.names = !file.exists(out))
