# Long-drought stand (plant-dev harness/long_drought.R): 108 uniform nodes,
# birth date, ode_tol 1e-3. OFFSET (days) sets storage_relaxation_offset; the
# probe build counts thrown stages (PROBE_THROW) and refused step ends
# (PROBE_STEPEND) on stderr. INVADERS: lma factors to replay on the run's steps.
source("/home/user/plant-dev/harness/long_drought.R")
# Run with PLANT_LIB set: without it the harness load_all()s the plant-dev
# submodule, whatever it holds. Refuse a plant without the offset this sets.
message("plant: ", getNamespaceInfo("plant", "path"))
stopifnot("storage_relaxation_offset" %in%
          names(scm_base_parameters("TF24")$strategy_default$pars))
offset <- as.numeric(Sys.getenv("OFFSET", "7"))
inv <- as.numeric(strsplit(Sys.getenv("INVADERS", ""), ",")[[1]])
set_offset <- function(p) {
  for (i in seq_along(p$strategies)) {
    s <- p$strategies[[i]]; s$pars$storage_relaxation_offset <- offset / 365
    p$strategies[[i]] <- s
  }
  p
}
times <- uniform_times(108)
p <- set_offset(stand_at(times))
ct <- control(); ct$ode_tol_rel <- 1e-3; ct$ode_tol_abs <- 1e-3
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(AK))))
t0 <- proc.time()[["elapsed"]]
scm <- run_scm(p, mkenv(), ct, events = ev)
cat(sprintf("RESULT offset %g d: J %.9f, accepted %d, %.0f s\n", offset,
            sum(scm$offspring_production), length(scm$ode_times),
            proc.time()[["elapsed"]] - t0))
message("PROBE_RESIDENT_DONE")
for (f in inv) {
  t0 <- proc.time()[["elapsed"]]
  q <- set_offset(stand_at(times, "lma", f))
  r <- tryCatch({ scm$run_mutant(q); sprintf("J' %.6g", sum(scm$offspring_production)) },
                error = function(e) paste("ERROR", conditionMessage(e)))
  cat(sprintf("RESULT invader lma x%g: %s (%.0f s)\n", f, substr(r, 1, 160),
              proc.time()[["elapsed"]] - t0))
}
