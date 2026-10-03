# Q1: on bounded Cash-Karp's accepted steps (the driver's SOIL_DIAG and COUPLED_REF runs),
# which component binds by regime, the uptake's share of the soil's budget, Cash-Karp's
# embedded soil estimate against the chain alone's, the chain alone's against the coupled
# reference, the members' headroom, and the candidate flags for Q3.
#   Rscript q1_report.R runs/q1_ld.rds [runs/q1_epi.rds ...]
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
Sys.setenv(PLANT_LIB = file.path(D, "lib_sw"))
source(file.path(D, "pf_soil/harness/long_drought.R"))
plant_runs <- c("long-drought" = file.path(D, "phase1c/combined/full/bnd_ld.rds"),
                episodic = file.path(D, "phase1c/combined/full/bnd_epi.rds"))
jstar <- c("long-drought" = 12.6687135, episodic = 1.978902094)
q <- function(x, p = c(0.25, 0.5, 0.75)) quantile(x, p, na.rm = TRUE, names = FALSE)
pct <- function(x) sprintf("%5.1f%%", 100 * mean(x, na.rm = TRUE))
DAY <- 1 / 365

# Each step's regime from the rainfall interpolant on a 0.05-day grid and at the step's
# start, middle and end (the driver's rain0, rainm, rain1).
regimes <- function(st, d, regime) {
  env <- mkenv(regime)
  g <- seq(0, LIFETIME, by = 0.05 * DAY)
  wet_g <- pmax(0, env$extrinsic_drivers_evaluate_range("rainfall", g)) > 0
  t0 <- d$t0; t1 <- d$t0 + d$h
  i0 <- findInterval(t0, g); i1 <- findInterval(t1, g)
  cw <- cumsum(wet_g)
  inside <- (cw[pmax(i1, 1)] - cw[pmax(i0, 1)]) > 0 & i1 > i0
  wet <- inside | d$rain0 > 0 | d$rainm > 0 | d$rain1 > 0
  # the last wet grid point at or before t0, and the last dry one
  last_wet <- cummax(ifelse(wet_g, seq_along(g), 0L))
  last_dry <- cummax(ifelse(!wet_g, seq_along(g), 0L))
  since_rain <- (t0 - g[pmax(1, last_wet[pmax(i0, 1)])]) / DAY
  since_rain[last_wet[pmax(i0, 1)] == 0] <- Inf
  spell_start <- g[pmin(length(g), last_dry[pmax(i0, 1)] + 1)]
  since_spell <- (t0 - spell_start) / DAY
  reg <- ifelse(wet, ifelse(since_spell < 1, "wet-onset", "wet"),
                ifelse(since_rain <= 1, "dry<=1d", ifelse(since_rain <= 10, "dry1-10d", "dry>10d")))
  factor(reg, levels = c("wet-onset", "wet", "dry<=1d", "dry1-10d", "dry>10d"))
}

for (f in commandArgs(TRUE)) {
  x <- readRDS(f)
  regime <- x$regime
  cat(sprintf("\n######## %s (%s)\n", regime, basename(f)))
  st <- x$st
  d <- x$diag
  a <- d[d$accepted == 1, ]
  stopifnot(nrow(a) == nrow(st), isTRUE(all.equal(a$t0 + a$h, st$time, tolerance = 0)) ||
            max(abs(a$t0 + a$h - st$time)) < 1e-12)
  # gate: the driver's run against plant's own bounded run
  b <- readRDS(plant_runs[[regime]])
  pt <- b$stand$times[-1]; ps <- b$stand$sizes[-1]
  same <- length(pt) == nrow(st) && identical(pt, st$time) && identical(ps, st$h)
  cat(sprintf("gate: driver %d accepted, plant %d; times and sizes %s; J %.9f vs plant %.9f (J/J* - 1 %+.2e)\n",
              nrow(st), length(pt), if (same) "identical" else "DIFFER", x$J, b$stand$J, x$J / jstar[[regime]] - 1))
  a$reg <- regimes(st, a, regime)
  a$rows <- a$M
  grp <- c("soil", "accumulator", "member", "storage")[a$grp]
  a$soilbound <- a$grp == 1
  cat(sprintf("accepted %d, rows %.0f; binding: soil %s, accumulator %s, member %s (storage %s within)\n",
              nrow(a), sum(a$rows), pct(a$grp == 1), pct(a$grp == 2), pct(a$grp %in% 3:4), pct(a$grp == 4)))

  cat("\n-- binding by regime (share of the regime's accepted steps), and the regime's share of steps and rows\n")
  cat(sprintf("%-10s %6s %6s %6s | %6s %6s %6s %6s | steps/rain-interval-day %s\n", "regime", "steps", "%steps", "%rows",
              "soil", "acc", "member", "storage", ""))
  for (r in levels(a$reg)) {
    s <- a$reg == r
    cat(sprintf("%-10s %6d %6s %6s | %6s %6s %6s %6s\n", r, sum(s), pct(s), sprintf("%5.1f%%", 100 * sum(a$rows[s]) / sum(a$rows)),
                pct(a$grp[s] == 1), pct(a$grp[s] == 2), pct(a$grp[s] == 3), pct(a$grp[s] == 4)))
  }

  cat("\n-- the uptake's share of the binding layer's budget on soil-bound steps (stage-weighted), quartiles; chain-wide; at the start\n")
  for (r in levels(a$reg)) {
    s <- a$reg == r & a$soilbound
    if (!any(s)) next
    cat(sprintf("%-10s n %5d | binding layer %.2e %.2e %.2e | chain %.2e %.2e %.2e | start, chain %.2e %.2e %.2e | layer: %s\n", r, sum(s),
                q(a$share_bind[s])[1], q(a$share_bind[s])[2], q(a$share_bind[s])[3],
                q(a$share_chain[s])[1], q(a$share_chain[s])[2], q(a$share_chain[s])[3],
                q(a$share0_chain[s])[1], q(a$share0_chain[s])[2], q(a$share0_chain[s])[3],
                paste(names(table(a$lay_emb[s])), table(a$lay_emb[s]), sep = ":", collapse = " ")))
  }

  cat("\n-- Cash-Karp's embedded soil estimate against the chain alone's: rho = R_emb / R_true (largest weighted layer ratio each)\n")
  a$rho <- a$r_emb / a$r_true
  for (sel in c("all accepted", "soil-bound")) {
    cat(sprintf("  %s:\n", sel))
    for (r in c(levels(a$reg), "all")) {
      s <- (if (r == "all") rep(TRUE, nrow(a)) else a$reg == r) & (if (sel == "soil-bound") a$soilbound else TRUE) &
        is.finite(a$rho) & a$r_true > 0
      if (!any(s)) next
      qq <- q(a$rho[s], c(0.1, 0.25, 0.5, 0.75, 0.9))
      cat(sprintf("  %-10s n %5d | rho p10 %.2f p25 %.2f median %.2f p75 %.2f p90 %.2f | rho<1 %s rho<0.5 %s rho>2 %s | R_true median %.3f (R_emb %.3f)\n",
                  r, sum(s), qq[1], qq[2], qq[3], qq[4], qq[5], pct(a$rho[s] < 1), pct(a$rho[s] < 0.5),
                  pct(a$rho[s] > 2), median(a$r_true[s]), median(a$r_emb[s])))
    }
  }
  # Under the chain alone's estimate, which soil-bound steps would the soil still bind?
  s <- a$soilbound
  other <- pmax(a$r_mem, a$r_acc)
  cat(sprintf("  soil-bound steps whose chain-alone soil ratio would still exceed every other component's: %s\n",
              pct(a$r_true[s] > other[s])))

  # the chain alone against the coupled reference
  if (!is.null(x$ref)) {
    rf <- x$ref[x$ref$ok == 1, ]
    m <- match(rf$t0, a$t0)
    rf$reg <- a$reg[m]; rf$soilbound <- a$soilbound[m]; rf$share0 <- a$share0_chain[m]
    Rref <- apply(rf[, paste0("rref_", 1:5)], 1, max)
    Rtrue <- apply(rf[, paste0("rtrue_", 1:5)], 1, max)
    Remb <- apply(rf[, paste0("remb_", 1:5)], 1, max)
    rf$dev <- abs(Rtrue - Rref) / Rref
    rf$emb_ref <- Remb / Rref
    cat(sprintf("\n-- the chain alone (linear uptake) against the coupled reference (%d sub-steps), every 10th accepted step (%d)\n",
                8, nrow(rf)))
    for (r in c(levels(a$reg), "all")) {
      s <- (if (r == "all") rep(TRUE, nrow(rf)) else rf$reg == r) & is.finite(rf$dev) & Rref > 0
      if (!any(s)) next
      cat(sprintf("  %-10s n %4d | |R_true - R_ref| / R_ref median %.3g p90 %.3g | R_emb / R_ref median %.2f p25 %.2f p75 %.2f | members: emb/ref median %.2f\n",
                  r, sum(s), median(rf$dev[s]), q(rf$dev[s], 0.9), median(rf$emb_ref[s]), q(rf$emb_ref[s], 0.25), q(rf$emb_ref[s], 0.75),
                  median((rf$rmem_emb / rf$rmem_ref)[s], na.rm = TRUE)))
    }
  }

  cat("\n-- the members' headroom on soil-bound steps: R_soil / R_mem (members incl. storage), and the step growth it allows, (.)^(1/5)\n")
  a$head <- a$ratio / pmax(a$r_mem, 1e-300)
  for (r in levels(a$reg)) {
    s <- a$reg == r & a$soilbound
    if (!any(s)) next
    qq <- q(a$head[s])
    cat(sprintf("  %-10s n %5d | R_soil / R_mem p25 %.3g median %.3g p75 %.3g | growth median %.2f | step median %.3f d\n",
                r, sum(s), qq[1], qq[2], qq[3], qq[2]^(1 / 5), 365 * median(a$h[s])))
  }

  cat("\n-- candidate flags for Q3: chain-wide uptake share at the step's start below s*\n")
  for (sstar in c(0.005, 0.01, 0.02, 0.05, 0.1)) {
    fl <- a$share0_chain < sstar
    sb <- fl & a$soilbound
    devf <- if (!is.null(x$ref)) rf$dev[rf$share0 < sstar & is.finite(rf$dev)] else NA
    cat(sprintf("  s* %5.3f | flagged %s of steps, %s of rows; in dry>10d %s; soil-bound among flagged %s (%s of rows) | headroom median %.3g | ref dev median %.3g (n %d)\n",
                sstar, pct(fl), sprintf("%5.1f%%", 100 * sum(a$rows[fl]) / sum(a$rows)), pct(a$reg[fl] == "dry>10d"),
                pct(a$soilbound[fl]), sprintf("%5.1f%%", 100 * sum(a$rows[sb]) / sum(a$rows)), median(a$head[sb]),
                median(devf), length(devf)))
    cat(sprintf("           flagged by regime: %s\n", paste(names(table(a$reg[fl])), table(a$reg[fl]), sep = ":", collapse = " ")))
  }
  # Rejected attempts: which component, by regime
  rj <- d[d$accepted == 0, ]
  cat(sprintf("\nrejected attempts with an estimate: %d; soil-bound %s; rho median on the soil-bound %.2f\n",
              nrow(rj), pct(rj$grp == 1), median((rj$r_emb / rj$r_true)[rj$grp == 1], na.rm = TRUE)))
  saveRDS(a, sub("\\.rds$", "_accepted.rds", f))
}
