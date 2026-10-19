# The toy System of odelia tests/testthat/test-substeps.R, with counters and a
# log added by text substitution, compiled against the installed odelia.
# Sourced with the working directory at an odelia checkout of ODELIA-55 (bfa32cf)
# and that build first on .libPaths().
library(odelia)
testthat::source_test_helpers("tests/testthat", env = globalenv())
toy <- parse("tests/testthat/test-substeps.R")
for (e in toy[1:4]) eval(e)

counted <- store_system
counted <- sub("void compute_rates() {",
  paste("void compute_rates() { ++n_full;",
        "if (logging) { log_t.push_back(time); log_w1.push_back(odelia::util::to_passive(w1));",
        "log_kind.push_back(0); }"), counted, fixed = TRUE)
counted <- sub("      store_rates(t, w, out);\n      out[0] -= u[0];",
  paste("      ++n_sub; if (logging) { log_t.push_back(t);",
        "log_w1.push_back(odelia::util::to_passive(w[0])); log_kind.push_back(1); }\n",
        "      store_rates(t, w, out);\n      out[0] -= u[0];"), counted, fixed = TRUE)
stopifnot(grepl("++n_full", counted, fixed = TRUE), grepl("++n_sub", counted, fixed = TRUE))

ensure_ode_interface_loaded()
odelia_so <- .odelia_test_cache$odelia_so
withr::local_envvar(
  PKG_CPPFLAGS = odelia_cppflags(odelia_include_dir()),
  PKG_LIBS = shQuote(normalizePath(odelia_so, winslash = "/", mustWork = TRUE)))
Rcpp::sourceCpp(code = paste0('
  // [[Rcpp::plugins(cpp20)]]
  #include <Rcpp.h>
  #include <algorithm>
  #include <cmath>
  #include <limits>
  #include <vector>
  #include <odelia/drivers.hpp>
  #include <odelia/ode_solver.hpp>
  static long n_full = 0, n_sub = 0;
  static bool logging = false;
  static std::vector<double> log_t, log_w1, log_kind;
  ', counted, '
  using namespace odelia;
  using StoreA = Store<double, true>;
  using StoreP = Store<double, false>;
  ode::OdeControl control_at(double tol) {
    ode::OdeControl ctl;
    ctl.set_tol_abs(tol);
    ctl.set_tol_rel(tol);
    ctl.set_controller(ode::Controller::gsl);
    return ctl;
  }

  // A run, plain (share < 0) or substepped at `share`: final state, accepted
  // steps, evaluations of the whole System and of the subsystem alone, and per
  // step its start, size and substep count.
  // [[Rcpp::export]]
  Rcpp::List counted_run(double share, double tol, double t_end,
                         std::vector<double> p, std::vector<double> y0) {
    n_full = 0; n_sub = 0;
    std::vector<double> y, start, size, nsub;
    int steps = 0;
    if (share < 0) {
      ode::Solver<StoreP> s(StoreP(p[0], p[1], p[2], p[3], p[4]), control_at(tol));
      s.set_state(y0, 0.0);
      s.advance_adaptive({0.0, t_end});
      y = s.state();
      auto prog = s.schedule();
      steps = prog.size() - 1;
      for (size_t k = 1; k < prog.size(); ++k) {
        start.push_back(prog[k - 1].time); size.push_back(prog[k].step_size); nsub.push_back(0);
      }
    } else {
      StoreA a(p[0], p[1], p[2], p[3], p[4]);
      a.substep_below = share;
      ode::Solver<StoreA> s(a, control_at(tol));
      s.set_state(y0, 0.0);
      s.advance_adaptive({0.0, t_end});
      y = s.state();
      auto prog = s.schedule();
      steps = prog.size() - 1;
      for (size_t k = 1; k < prog.size(); ++k) {
        start.push_back(prog[k - 1].time); size.push_back(prog[k].step_size);
        nsub.push_back(prog[k].subsystem ? prog[k].subsystem->ends.size() : 0);
      }
    }
    return Rcpp::List::create(Rcpp::_["y"] = y, Rcpp::_["steps"] = steps,
      Rcpp::_["full"] = (double) n_full, Rcpp::_["sub"] = (double) n_sub,
      Rcpp::_["start"] = start, Rcpp::_["size"] = size, Rcpp::_["nsub"] = nsub);
  }

  // Step k of a substepped run, replayed alone from its recorded start with
  // the log on; and the same step size taken by the plain System from there.
  // [[Rcpp::export]]
  Rcpp::List one_step(double share, double tol, double t_end, int k,
                      std::vector<double> p, std::vector<double> y0) {
    StoreA a(p[0], p[1], p[2], p[3], p[4]);
    a.substep_below = share;
    ode::Solver<StoreA> s(a, control_at(tol));
    s.set_keep_states(true);
    s.set_state(y0, 0.0);
    s.advance_adaptive({0.0, t_end});
    auto rec = s.recording();
    const auto& row = rec[k];
    const double t0 = rec[k - 1].time;
    std::vector<double> ystart = rec[k - 1].state;
    std::vector<ode::instruction> prog{{t0, std::numeric_limits<double>::quiet_NaN()},
                                       {row.time, row.step_size, false, row.subsystem}};
    ode::Solver<StoreA> r(a, control_at(tol));
    log_t.clear(); log_w1.clear(); log_kind.clear();
    logging = true;
    r.set_state(ystart, t0);
    r.advance_recorded(prog);
    logging = false;
    Rcpp::List out = Rcpp::List::create(
      Rcpp::_["t0"] = t0, Rcpp::_["h"] = row.step_size, Rcpp::_["ystart"] = ystart,
      Rcpp::_["yend"] = r.state(), Rcpp::_["yend_run"] = rec[k].state,
      Rcpp::_["ends"] = row.subsystem ? row.subsystem->ends : std::vector<double>{},
      Rcpp::_["slope"] = row.subsystem ? row.subsystem->input_slope : std::vector<double>{},
      Rcpp::_["log_t"] = log_t, Rcpp::_["log_w1"] = log_w1, Rcpp::_["log_kind"] = log_kind);
    // The plain System over the same step.
    StoreP q(p[0], p[1], p[2], p[3], p[4]);
    ode::Solver<StoreP> pl(q, control_at(tol));
    log_t.clear(); log_w1.clear(); log_kind.clear();
    logging = true;
    pl.set_state(ystart, t0);
    pl.advance_recorded(std::vector<ode::instruction>{{t0, std::numeric_limits<double>::quiet_NaN()},
                                                      {row.time, row.step_size}});
    logging = false;
    out["plain_t"] = log_t; out["plain_w1"] = log_w1; out["plain_end"] = pl.state();
    // A tight plain run over the step, every state it reached.
    ode::Solver<StoreP> ref(q, control_at(1e-12));
    ref.set_keep_states(true);
    ref.set_state(ystart, t0);
    ref.advance_adaptive({t0, row.time});
    std::vector<double> rt, rw;
    for (const auto& rr : ref.recording()) { rt.push_back(rr.time); rw.push_back(rr.state[1]); }
    out["ref_t"] = rt; out["ref_w1"] = rw;
    return out;
  }
'), verbose = FALSE)
