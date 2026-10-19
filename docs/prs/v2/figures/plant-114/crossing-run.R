# plant-114: how often the crowns are out of height order, on B97 (no sort).
# The synthetic 41-year record's stand (harness/long_drought.R: one TF24 species
# at lma 0.32, 108 uniform introductions, birth date, ode_tol 1e-3, a stop at
# every rain knot). At each stop (introductions and rain knots; the run stops
# there anyway, so the steps are the run's own) it records whether the
# cohorts' heights fall along the node list, oldest first, as the light build's
# scan checks them; and every node's height at the stop with the widest pair.
#   PLANT_LIB=<B97> Rscript crossing-run.R
source("/home/user/plant-dev/harness/long_drought.R")
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-114"
times <- uniform_times(108)
p <- stand_at(times)
ctrl <- Control(node_density_in_birth_date = TRUE, ode_tol_rel = 1e-3, ode_tol_abs = 1e-3)
scm <- run_scm(p, mkenv(), ctrl, events = events(events_default(p), pulse_rows(AK)), run = FALSE)
stops <- sort(unique(c(times[-1], AK, LIFETIME)))
rows <- list(); widest <- NULL; gap_max <- 0
for (t in stops) {
  scm$run_to(t)
  sp <- scm$patch$species[[1]]
  h <- sp$heights
  up <- diff(h)                       # > 0: a younger cohort taller than the one before it
  rows[[length(rows) + 1]] <- data.frame(t = scm$patch$time, nodes = length(h),
    pairs_out_of_order = sum(up > 0), widest_mm = 1000 * max(c(0, up)))
  if (max(c(0, up)) > gap_max) {
    gap_max <- max(up)
    widest <- data.frame(t = scm$patch$time, birth = sp$node_times[seq_along(h)],
                         height = h, crossed = c(up > 0, FALSE) | c(FALSE, up > 0))
  }
  if (scm$complete) break
}
d <- do.call(rbind, rows)
write.csv(d, file.path(here, "crossing-share.csv"), row.names = FALSE)
write.csv(widest, file.path(here, "crossing-heights.csv"), row.names = FALSE)
cat(sprintf("stops %d, out of order at %d (%.1f%%), first t %.2f, most pairs %d, widest %.3f mm at t %.3f; J %.9f\n",
            nrow(d), sum(d$pairs_out_of_order > 0), 100 * mean(d$pairs_out_of_order > 0),
            min(d$t[d$pairs_out_of_order > 0]), max(d$pairs_out_of_order), 1000 * gap_max,
            widest$t[1], sum(scm$offspring_production)))
