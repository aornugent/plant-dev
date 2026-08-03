# Shared helpers for the schedule_eps Pareto sweep (probes 40-49).
#
# Re-implements SCM::refine_schedule() in R using the exposed hooks
# (collect_refinement_errors / refinement_error_by_node / set_node_schedule_times)
# so that every refinement iteration can be recorded.  Validated against the C++
# loop in 40-validate.R.
suppressMessages(library(plant))

TRAITS <- list(K93 = trait_matrix(0.059, "b_0"),
               FF16 = trait_matrix(0.0825, "lma"),
               TF24 = trait_matrix(0.1978791, "lma"))

make_scm <- function(model, bd, eps = NULL, nsteps = NULL) {
  p <- add_strategies(scm_base_parameters(model, paste0(model, "_Env")),
                      TRAITS[[model]])
  ct <- Control()
  ct$node_density_in_birth_date <- bd
  if (!is.null(eps)) ct$schedule_eps <- eps
  if (!is.null(nsteps)) ct$schedule_nsteps <- nsteps
  ty <- plant:::extract_RcppR6_template_types(p, "Parameters")
  do.call(plant:::SCM, ty)(p, Environment(model), ct)
}

# C++ bisect_flagged_intervals: for each flagged node j (0-based j >= 1) insert
# the midpoint of the interval below it.  R indices j = 2..n.
bisect_flagged <- function(times, split) {
  j <- which(split)
  j <- j[j >= 2]
  sort(c(times, 0.5 * (times[j] + times[j - 1])))
}

# One refinement sweep, recording each iteration.  Returns a list with a
# per-iteration data.frame and the final diagnostics.
refine_traced <- function(model, bd, eps, nsteps = 20, budget_s = Inf,
                          verbose = TRUE, keep_final = TRUE) {
  scm <- make_scm(model, bd, eps, nsteps)
  scm$collect_refinement_errors <- TRUE
  rows <- list()
  t_all <- Sys.time()
  converged <- NA
  final <- NULL
  times_run <- scm$parameters$node_schedule_times[[1]]
  for (it in seq_len(nsteps)) {
    t0 <- Sys.time()
    err <- tryCatch({ scm$run(); scm$refinement_error_by_node },
                    error = function(e) structure(list(), msg = conditionMessage(e)))
    dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (!length(err)) {
      rows[[length(rows) + 1]] <- data.frame(
        model = model, bd = bd, eps = eps, iter = it,
        n_run = length(times_run), n_ode = NA_integer_, value = NA_real_,
        n_flag = NA_integer_, secs = dt, status = "error")
      converged <- FALSE
      attr(rows, "msg") <- attr(err, "msg")
      break
    }
    e1 <- err[[1]]
    flag <- !is.na(e1) & is.finite(e1) & e1 > eps
    val <- scm$offspring_production[[1]]
    n_ode <- length(scm$ode_times)
    rows[[length(rows) + 1]] <- data.frame(
      model = model, bd = bd, eps = eps, iter = it,
      n_run = length(times_run), n_ode = n_ode, value = val,
      n_flag = sum(flag), secs = dt, status = "ok")
    if (verbose)
      cat(sprintf("  [%s %s eps=%-9.3g] iter %2d  n=%-5d ode=%-6d val=%-12.8g flag=%-4d %6.1fs\n",
                  model, if (bd) "bd" else "ht", eps, it, length(times_run),
                  n_ode, val, sum(flag), dt), file = stderr())
    if (keep_final)
      final <- list(times = times_run, err = e1,
                    rep_err = scm$net_reproduction_ratio_errors[[1]],
                    value = val, n_ode = n_ode,
                    ode_times = scm$ode_times)
    if (!any(flag)) { converged <- TRUE; break }
    if (as.numeric(difftime(Sys.time(), t_all, units = "secs")) > budget_s) {
      converged <- NA; break
    }
    times_run <- bisect_flagged(times_run, flag)
    scm$reset()
    scm$set_node_schedule_times(list(times_run))
    if (it == nsteps) converged <- FALSE
  }
  list(rows = do.call(rbind, rows), converged = converged, final = final,
       total_s = as.numeric(difftime(Sys.time(), t_all, units = "secs")))
}

# Fixed schedule with the default times uniformly bisected `k` times
# (141 -> 281 -> 561 -> 1121 ...), no refinement.
bisect_uniform <- function(times, k) {
  for (i in seq_len(k)) times <- sort(c(times, 0.5 * (times[-1] + times[-length(times)])))
  times
}

run_fixed <- function(model, bd, k) {
  scm <- make_scm(model, bd)
  tt <- bisect_uniform(scm$parameters$node_schedule_times[[1]], k)
  scm$reset(); scm$set_node_schedule_times(list(tt))
  t0 <- Sys.time()
  scm$run()
  data.frame(model = model, bd = bd, k = k, n = length(tt),
             n_ode = length(scm$ode_times),
             value = scm$offspring_production[[1]],
             secs = as.numeric(difftime(Sys.time(), t0, units = "secs")))
}
