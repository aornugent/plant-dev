# regnans's equilibrium root-finders on the TF24 stand, counting runs: its own
# target and util_nlsolve, sourced from a regnans checkout, driven by a runner
# b -> J(b) on held node times, as its demography runner would be once it runs
# on this plant.
#
#   PLANT_LIB=... REGNANS_DIR=... SOLVER=nleqslv|dfsane [TOL=1e-4] [ATOL=1e-4] \
#     [NODES=108] [SPLIT=1] [MAX_RUNS=25] OUT=solver.rds Rscript harness/regnans_solvers.R
#
# The glue between them, demography_solve_equilibrium_solve's body for one species
# kept, is copied from regnans's R/community_demography.R. The runner stops the
# solve after MAX_RUNS runs.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
regnans <- Sys.getenv("REGNANS_DIR")
solver <- Sys.getenv("SOLVER", "nleqslv")
tol <- as.numeric(Sys.getenv("TOL", "1e-4"))
atol <- as.numeric(Sys.getenv("ATOL", "1e-4"))
nodes <- as.integer(Sys.getenv("NODES", "108"))
max_runs <- as.integer(Sys.getenv("MAX_RUNS", "25"))
out_file <- Sys.getenv("OUT")
plant_log_eq <- function(...) invisible(NULL)
source(file.path(regnans, "R", "util_nlsolve.R"))
local({
  # Only demography_solve_equilibrium_solve_target is taken from this file.
  e <- new.env()
  sys.source(file.path(regnans, "R", "community_demography.R"), envir = e)
  assign("target_of", e$demography_solve_equilibrium_solve_target, envir = globalenv())
})
environment(target_of) <- globalenv()

times <- uniform_times(nodes)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE
if (Sys.getenv("SPLIT") == "1") ct$ode_split_sign_changes <- TRUE
stand <- function(b) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"))
  p$strategies[[1]]$birth_rate_y <- b
  p$node_schedule_times <- list(times)
  p
}
ev <- events(events_default(stand(1)), pulse_rows(sort(unique(active_knots(SCEN)))))
env <- mkenv(SCEN)

runs <- list()
save <- function() if (nzchar(out_file)) saveRDS(list(solver = solver, runs = runs), out_file)
runner <- function(b) {
  if (length(runs) >= max_runs) stop("stopped after ", max_runs, " runs")
  t0 <- proc.time()[["elapsed"]]
  scm <- run_scm(stand(b), env, ct, events = ev)
  J <- sum(scm$offspring_production)
  runs[[length(runs) + 1L]] <<- list(b = b, J = J, f = log(J) - log(b),
                                     secs = proc.time()[["elapsed"]] - t0)
  save()
  cat(sprintf("%-8s run %2d  b %.10g  J %.10g  ln J - ln b %+.3e\n", solver,
              length(runs), b, J, log(J) - log(b)))
  J
}

# demography_solve_equilibrium_solve, for one species from b = 1, at regnans's
# defaults: logN, try_keep, equilibrium_eps 1e-5, min 1e-10, maxit 100.
birth_rates <- 1
keep <- unname(runner(birth_rates) >= birth_rates)
target <- target_of(runner, keep, TRUE, 1e-10, pmax(birth_rates * 100, 10000))
sol <- tryCatch(util_nlsolve(log(birth_rates), target, tol = 1e-5, maxit = 100,
                             solver = solver, require_converged = FALSE),
                error = function(e) structure(NA_real_, error = conditionMessage(e)))
out <- list(solver = solver, runs = runs, keep = keep,
            root = exp(as.numeric(sol)), attributes = attributes(sol))
if (nzchar(out_file)) saveRDS(out, out_file)
cat(sprintf("%s: %d runs, root b %.10g, %s\n", solver, length(runs), out$root,
            if (!is.null(attr(sol, "error"))) attr(sol, "error") else
              paste("converged", isTRUE(attr(sol, "converged")), attr(sol, "message"))))
