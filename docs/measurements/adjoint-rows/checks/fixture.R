# A short long-drought TF24 stand: LIFETIME years, NODES uniform introductions,
# a zero-depth pulse at every active rainfall knot (each an insertion row with no
# node), hmat lowered to 6 m so cohorts reproduce inside the run.
Sys.setenv(LIFETIME = Sys.getenv("LIFETIME", "8"))
source("/home/user/plant-dev/harness/long_drought.R")
NODES <- as.integer(Sys.getenv("NODES", "16"))
TOL <- as.numeric(Sys.getenv("TOL", "1e-3"))

fixture_parameters <- function(birth_rate = 1, lma = LMA0) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(c(lma, 6), c("lma", "hmat")),
                      birth_rate = birth_rate)
  p$node_schedule_times <- list(seq(0, LIFETIME * (NODES - 1) / NODES,
                                    length.out = NODES))
  p
}
fixture_control <- function() {
  ct <- control()
  ct$ode_tol_rel <- TOL
  ct$ode_tol_abs <- TOL
  ct$node_density_in_birth_date <- TRUE
  ct
}
fixture_run <- function(p = fixture_parameters()) {
  ev <- if (length(AK) == 0) NULL else events(events_default(p), pulse_rows(AK))
  run_scm(p, mkenv(), fixture_control(), events = ev, record_trajectory = TRUE)
}
vmhwm <- function() {
  x <- readLines("/proc/self/status")
  as.numeric(gsub("[^0-9]", "", x[grepl("^VmHWM", x)])) / 1024
}
