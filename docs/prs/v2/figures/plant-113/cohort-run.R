# plant-113 mechanism data: one real seedling cohort through a dry spell.
# The synthetic record's stand (harness/long_drought.R, 108 introductions, birth
# date, ode_tol 1e-3, rain-knot stops) on B97 at the default offset of 7 d, with
# extra stops (zero-depth pulses) every 6 hours from t = 3.36 to 3.80 yr, recording the cohort
# born at t = 2.963 yr: its height, storage and net production P.
#   PLANT_LIB=<B97> Rscript cohort-run.R
source("/home/user/plant-dev/harness/long_drought.R")
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-113"
times <- uniform_times(108)
p <- stand_at(times)
ctrl <- Control(node_density_in_birth_date = TRUE, ode_tol_rel = 1e-3, ode_tol_abs = 1e-3)
birth <- times[[9]]
dense <- seq(3.36, 3.80, by = 0.25 / 365)
# The extra stops are zero-depth pulses too, since a run stops only at events.
scm <- run_scm(p, mkenv(), ctrl,
               events = events(events_default(p), pulse_rows(sort(unique(c(AK, dense))))),
               run = FALSE)
rows <- list()
for (t in sort(unique(c(dense, AK[AK > 3.3 & AK < 3.8], times[times > 3.3 & times < 3.8])))) {
  scm$run_to(t)
  if (t < 3.36) next
  nn <- scm$patch$species[[1]]$nodes
  k <- which(vapply(nn, function(n) abs(n$introduction_time - birth) < 1e-9, TRUE))
  ind <- nn[[k]]$individual
  s <- setNames(ind$internals$states, ind$ode_names)
  rows[[length(rows) + 1]] <- data.frame(t = scm$patch$time, birth = birth,
    height = s[["height"]], storage = s[["storage"]],
    P = ind$aux("net_mass_production_dt"))
}
d <- do.call(rbind, rows)
pr <- p$strategies[[1]]$pars
eta_c <- 1 - 2 / (1 + pr$eta) + 1 / (1 + 2 * pr$eta)
d$storage_max <- pr$a_st1 * (d$height / pr$a_l1)^(1 / pr$a_l2) * pr$theta *
  d$height * eta_c * pr$rho
write.csv(d, file.path(here, "cohort-run.csv"), row.names = FALSE)
cat(sprintf("rows %d, P changes sign at t = %s\n", nrow(d),
            paste(sprintf("%.4f", d$t[which(diff(sign(d$P)) != 0) + 1]), collapse = " ")))
