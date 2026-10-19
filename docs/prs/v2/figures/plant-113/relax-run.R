# plant-113: the storage pool's own relaxation rate lambda = (charge + drain)/S_max
# for every cohort under 1 m, at each introduction and rain-knot stop of the
# first 12 years of the synthetic record's stand (harness/long_drought.R, 108
# introductions, birth date, ode_tol 1e-3) on B97, offset 7 d.
#   PLANT_LIB=<B97> Rscript relax-run.R
source("/home/user/plant-dev/harness/long_drought.R")
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-113"
times <- uniform_times(108)
p <- stand_at(times)
ctrl <- Control(node_density_in_birth_date = TRUE, ode_tol_rel = 1e-3, ode_tol_abs = 1e-3)
scm <- run_scm(p, mkenv(), ctrl, events = events(events_default(p), pulse_rows(AK)), run = FALSE)
pr <- p$strategies[[1]]$pars
eta_c <- 1 - 2 / (1 + pr$eta) + 1 / (1 + 2 * pr$eta)
cap <- function(h) pr$a_st1 * (h / pr$a_l1)^(1 / pr$a_l2) * pr$theta * h * eta_c * pr$rho
rows <- list()
for (t in sort(unique(c(times[-1], AK)))) {
  if (t > 12) break
  scm$run_to(t)
  for (n in scm$patch$species[[1]]$nodes) {
    ind <- n$individual
    s <- setNames(ind$internals$states, ind$ode_names)
    if (s[["height"]] >= 1) next
    rows[[length(rows) + 1]] <- c(t = scm$patch$time, birth = n$introduction_time,
      height = s[["height"]], storage = s[["storage"]], P = ind$aux("net_mass_production_dt"))
  }
}
d <- as.data.frame(do.call(rbind, rows))
d$storage_max <- cap(d$height)
r <- d$storage / d$storage_max
Pp <- 0.5 * (d$P + sqrt(d$P^2 + 1e-8))
G <- 1 / (1 + exp(-(r - pr$a_st2) / 0.1))
d$lambda <- (Pp * (1 - G) + Pp - d$P) / d$storage_max
write.csv(d, file.path(here, "relax-run.csv"), row.names = FALSE)
cat(sprintf("%d cohort-stops; lambda quantiles 50/90/99/max: %s /yr\n", nrow(d),
            paste(sprintf("%.0f", quantile(d$lambda, c(0.5, 0.9, 0.99, 1))), collapse = " ")))
