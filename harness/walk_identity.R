# The invader at the stand's own traits, walked on the stand's recorded run at a
# birth rate of 1, against the stand's own J / b, with splits off and on; then at
# a birth rate of 0, as regnans walks its mutants, read per capita.
#
#   PLANT_LIB=... B=4.659319023 [TOL=1e-4] [ATOL=1e-4] [NODES=108] OUT=walk.rds \
#     Rscript harness/walk_identity.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
b <- as.numeric(Sys.getenv("B"))
tol <- as.numeric(Sys.getenv("TOL", "1e-4"))
atol <- as.numeric(Sys.getenv("ATOL", "1e-4"))
nodes <- as.integer(Sys.getenv("NODES", "108"))
out_file <- Sys.getenv("OUT")
times <- uniform_times(nodes)
stand <- function(birth_rate) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"), birth_rate = birth_rate)
  p$node_schedule_times <- list(times)
  p
}
ev <- events(events_default(stand(1)), pulse_rows(sort(unique(active_knots(SCEN)))))
env <- mkenv(SCEN)
out <- list(b = b)
for (split in c(FALSE, TRUE)) {
  ct <- control()
  ct$ode_tol_rel <- tol
  ct$ode_tol_abs <- atol * tol
  ct$node_density_in_birth_date <- TRUE
  ct$ode_split_sign_changes <- split
  scm <- run_scm(stand(b), env, ct, events = ev, record_trajectory = TRUE)
  R <- sum(scm$offspring_production) / b
  splits <- scm$ode_splits
  scm$run_mutant(stand(1))
  Jw <- sum(scm$offspring_production)
  scm$run_mutant(stand(0))
  R0 <- scm$net_reproduction_ratios
  J0 <- sum(scm$offspring_production)
  key <- if (split) "split" else "plain"
  out[[key]] <- list(R = R, walked = Jw, gap = Jw / R - 1, splits = splits,
                     walked_at_0 = R0, offspring_at_0 = J0)
  if (nzchar(out_file)) saveRDS(out, out_file)
  cat(sprintf("%-6s J/b %.12f  walked J' %.12f  gap %+.3e  (%d node steps split)\n",
              key, R, Jw, Jw / R - 1, splits))
  cat(sprintf("       at birth rate 0: R' %.12f (%+.3e from J' at 1), offspring %g\n",
              R0, R0 / Jw - 1, J0))
}
