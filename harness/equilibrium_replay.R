# The stand at b* replayed on its own recorded program, against its adaptive
# run: the replay's cost and agreement at b*, and both at lma moved 1% alone.
#
#   PLANT_LIB=... B_STAR=4.659319023 [TOL=1e-4] [ATOL=1e-4] [NODES=108] [SPLIT=1] \
#     OUT=replay.rds Rscript harness/equilibrium_replay.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
b_star <- as.numeric(Sys.getenv("B_STAR"))
tol <- as.numeric(Sys.getenv("TOL", "1e-4"))
atol <- as.numeric(Sys.getenv("ATOL", "1e-4"))
nodes <- as.integer(Sys.getenv("NODES", "108"))
out_file <- Sys.getenv("OUT")
times <- uniform_times(nodes)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE
if (Sys.getenv("SPLIT") == "1") ct$ode_split_sign_changes <- TRUE
stand <- function(lma_rel = 0, program = NULL) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"))
  p$strategies[[1]]$pars$lma <- LMA0 * (1 + lma_rel)
  p$strategies[[1]]$birth_rate_y <- b_star
  p$node_schedule_times <- list(times)
  if (!is.null(program)) {
    p$ode_times <- program$times
    p$ode_step_sizes <- program$sizes
  }
  p
}
ev <- events(events_default(stand()), pulse_rows(sort(unique(active_knots(SCEN)))))
env <- mkenv(SCEN)
out <- list(b_star = b_star, runs = list())
one <- function(role, lma_rel, program = NULL) {
  t0 <- proc.time()[["elapsed"]]
  scm <- run_scm(stand(lma_rel, program), env, ct, events = ev)
  row <- list(role = role, lma_rel = lma_rel, J = sum(scm$offspring_production),
              secs = proc.time()[["elapsed"]] - t0, steps = length(scm$ode_times),
              attempts = sum(scm$ode_step_attempts))
  out$runs[[role]] <<- row
  if (nzchar(out_file)) saveRDS(out, out_file)
  cat(sprintf("%-16s lma x %.2f  J %.12g  %.0f s  %d steps  %d attempts\n", role,
              1 + lma_rel, row$J, row$secs, row$steps, row$attempts))
  scm
}
base <- one("adaptive", 0)
program <- list(times = base$ode_times, sizes = base$ode_step_sizes)
invisible(one("replay", 0, program))
invisible(one("adaptive_moved", 0.01))
invisible(one("replay_moved", 0.01, program))
