# The probe's light defect reconstructed in R from u108's recorded states at a
# few times, beside the field it perturbs, and the same defect from u215's real
# mid nodes (whose states are known there): is the interpolated virtual node
# like the real one?
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
Sys.setenv(PLANT_LIB = file.path(A, "lib"))
source(file.path(A, "harness", "long_drought.R"))
source(file.path(A, "probe_setup.R"))
scen <- "long-drought, seed 31"
RAIN_SPECS[[scen]] <- RAIN_SPECS[["long-drought"]]
knots <- active_knots(scen)
run <- function(times) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"))
  p$node_schedule_times <- list(times)
  ct <- control(); ct$ode_tol_rel <- 3e-5; ct$ode_tol_abs <- 3e-9
  ct$node_density_in_birth_date <- TRUE
  ev <- events(events_default(p), pulse_rows(sort(unique(knots))))
  run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
}
TT <- c(2, 5, 8, 9.5, 12, 15, 20)
snap <- function(scm, times) {
  rows <- scm$store_trajectory()
  t <- vapply(rows, `[[`, 0, "time")
  sp <- scm$patch$species[[1]]
  nm <- sp$new_node$ode_names; per <- length(nm)
  bt <- sp$node_times
  lapply(TT, function(tt) {
    i <- max(which(t <= tt & !vapply(rows, function(r) isTRUE(r$introduction), TRUE)))
    s <- rows[[i]]$state
    n <- sum(bt < t[i])
    m <- matrix(s[seq_len(per * n)], nrow = per, dimnames = list(nm))
    list(t = t[i], birth = bt[seq_len(n)], H = m["height", ], mu = m["mortality", ],
         I = m["interval_establishment", ], M = m["interval_establishment_moment", ])
  })
}
s108 <- snap(run(readRDS(file.path(A, "ref", "t_u108.rds"))), TT)
s215 <- snap(run(readRDS(file.path(A, "ref", "t_u215.rds"))), TT)
saveRDS(list(s108 = s108, s215 = s215), file.path(A, "out", "snapshots.rds"))
k_I <- 0.5; eta <- 12; Af <- function(h) (h / 5.44)^(1 / 0.306)
crown <- function(da, H, z) ifelse(z <= H, k_I * da * (1 - (z / H)^eta)^2, 0)
for (k in seq_along(TT)) {
  a <- s108[[k]]; f <- s215[[k]]
  cat(sprintf("t = %.3f (u215 at %.3f)\n", a$t, f$t))
  for (p in 1:3) {
    lo <- p; hi <- p + 1
    if (hi > length(a$H)) next
    jm <- 2 * p                                # u215's node between them
    lam <- 0.5
    Hv <- (a$H[lo] + a$H[hi]) / 2; muv <- (a$mu[lo] + a$mu[hi]) / 2
    cat(sprintf("  panel %d: u108 H %.3f %.3f -> virtual %.3f; u215 real mid H %.3f (its neighbours %.3f %.3f)\n",
                p, a$H[lo], a$H[hi], Hv, f$H[jm], f$H[jm - 1], f$H[jm + 1]))
    cat(sprintf("           mu %.3f %.3f -> virtual %.3f; u215 real mid mu %.3f (neighbours %.3f %.3f)\n",
                a$mu[lo], a$mu[hi], muv, f$mu[jm], f$mu[jm - 1], f$mu[jm + 1]))
    # density x leaf area of the virtual node against the linear share, both runs
    dA <- function(H, mu) exp(-mu) * Af(H)
    cat(sprintf("           dA: virtual %.4g vs share %.4g (ratio %.4f); u215 real %.4g vs its share %.4g (ratio %.4f)\n",
                dA(Hv, muv), (dA(a$H[lo], a$mu[lo]) + dA(a$H[hi], a$mu[hi])) / 2,
                dA(Hv, muv) / ((dA(a$H[lo], a$mu[lo]) + dA(a$H[hi], a$mu[hi])) / 2),
                dA(f$H[jm], f$mu[jm]), (dA(f$H[jm - 1], f$mu[jm - 1]) + dA(f$H[jm + 1], f$mu[jm + 1])) / 2,
                dA(f$H[jm], f$mu[jm]) / ((dA(f$H[jm - 1], f$mu[jm - 1]) + dA(f$H[jm + 1], f$mu[jm + 1])) / 2)))
  }
}
