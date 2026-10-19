# How often the crowns are out of height order: the long-drought harness stand at
# n uniform introductions, stopped at every leg end (introductions and rain knots),
# counting the leg ends where the node heights do not decrease.
# Usage: PLANT_LIB=... SCEN=<record> Rscript census.R <label> <n> <tol>
args <- commandArgs(TRUE)
label <- args[[1]]; n <- as.integer(args[[2]]); tol <- as.numeric(args[[3]])
source("/home/user/plant-dev/harness/long_drought.R")
scen <- Sys.getenv("SCEN", "long-drought")
AK <- active_knots(scen)
times <- uniform_times(n)
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(AK))))
scm <- run_scm(p, mkenv(scen), ct, events = ev, run = FALSE)
stops <- sort(unique(c(times[-1], AK, LIFETIME)))
out <- 0L; legs <- 0L; first <- NA; last <- NA; most <- 0L; gap <- 0
t0 <- proc.time()
for (t in stops) {
  scm$run_to(t)
  h <- scm$patch$species[[1]]$heights
  legs <- legs + 1L
  k <- sum(diff(h) > 0)
  if (k > 0) {
    out <- out + 1L; if (is.na(first)) first <- t; last <- t
    most <- max(most, k); gap <- max(gap, diff(h))
  }
  if (scm$complete) break
}
el <- proc.time() - t0
cat(sprintf(paste("%s %s n=%d tol=%g leg_ends=%d out_of_order=%d (%.1f%%) from t=%.2f to %.2f",
                  "most_pairs=%d max_gap_mm=%.3f J=%.10g elapsed=%.0f\n"),
            label, scen, n, tol, legs, out, 100 * out / legs, first, last, most,
            1000 * gap, sum(scm$offspring_production), el[["elapsed"]]))
