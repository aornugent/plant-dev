# The bounded combined setting (soil x10, rule A, a 15-day cap, each state's
# weight at most 100) against plant's own unweighted runs and against rule A
# with the 15-day cap alone, per record: cost, J's error, the soil's clamp
# tallies, both roles' moves and distance from 1e-5 in eps, and every walk; then
# C3, the setting's +-5% tolerance nudges on long drought.
#
#   Rscript bounded_table.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
C <- file.path(D, "phase1c/combined")
source(file.path(D, "phase1c/nudge_spread.R"))  # eps, eps_of, quantities
eps_lnJ <- eps$eps[eps$role == "resident" & eps$trait == "ln J"]
main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")
sc <- file.path(WT, "docs/measurements/spot-check")
recs <- list(
  "long-drought" = list(base = file.path(sc, "ld_3e-5.rds"), bnd = file.path(C, "full/bnd_ld.rds"),
                        ruleA = file.path(D, "phase1c/full/ld_h15.rds"), drv = file.path(D, "phase1c/drv/long-drought_ruleA_h15.log"),
                        ref = file.path(WT, "docs/measurements/nudges/ld_1e-5.rds"),
                        win = file.path(D, "window/runs/win_long-drought_u108.rds"), jstar = 12.6687135),
  "long-wet" = list(base = file.path(sc, "wet_base.rds"), bnd = file.path(C, "full/bnd_wet.rds"),
                    ruleA = file.path(D, "phase1c/full/wet_h15.rds"), drv = file.path(D, "phase1c/drv/long-wet_ruleA_h15.log"),
                    ref = file.path(C, "full/wet_1e-5.rds"),
                    win = file.path(D, "window/runs/win_long-wet_u108.rds"), jstar = file.path(D, "window/ref/wet_1e-8_abs.rds")),
  episodic = list(base = file.path(sc, "epi_base.rds"), bnd = file.path(C, "full/bnd_epi.rds"),
                  ruleA = file.path(D, "phase1c/full/epi_h15.rds"), drv = file.path(D, "phase1c/drv/episodic_ruleA_h15.log"),
                  ref = file.path(D, "phase1c/full/epi_1e-5.rds"),
                  win = file.path(D, "window/runs/win_episodic_u108.rds"), jstar = file.path(D, "window/ref/epi_1e-8_abs.rds")))
done <- function(f) file.exists(f) && !is.null(readRDS(f)$finished)
jstar_of <- function(j) if (is.numeric(j)) j else readRDS(j)$stand$J
# Rows: the members on each accepted step; forward: rows times attempts over
# accepted steps. A replayed program reports no rejections, so rule A's capped
# replays take their attempts from the driver's log.
rows_of <- function(x) sum(as.numeric(findInterval(head(x$stand$times, -1), sort(x$node_times))))
attempts_of_log <- function(f) {
  l <- paste(readLines(f), collapse = " ")
  v <- function(k) as.numeric(sub(sprintf(".*%s=([0-9]+).*", k), "\\1", l))
  c(accepted = v("accepted"), rejected_inaccurate = v("rejected_inaccurate"), rejected_thrown = v("rejected_thrown"))
}
cost <- function(x, a = x$stand$attempts) {
  ms <- rows_of(x)
  c(rows = ms, forward = ms * (a[["accepted"]] + a[["rejected_inaccurate"]] + a[["rejected_thrown"]]) / a[["accepted"]],
    accepted = a[["accepted"]], rejected = a[["rejected_inaccurate"]] + a[["rejected_thrown"]],
    longest = max(diff(x$stand$times)) * 365)
}
saving <- function(c1, c0) {
  s <- 1 - c1[c("rows", "forward")] / c0[c("rows", "forward")]
  sprintf("rows %+.1f%%, forward %+.1f%%, gradient run %+.1f%%", -100 * s[["rows"]], -100 * s[["forward"]],
          -100 * (1 - (c1[["forward"]] / c0[["forward"]] + 6 * c1[["rows"]] / c0[["rows"]]) / 7))
}
by_role <- function(d, n) {
  role <- sub(" .*", "", n); tr <- sub("^(resident|invader) ", "", n)
  vapply(c("resident", "invader"), function(ro) {
    s <- role == ro; m <- s & tr %in% main
    sprintf("%-8s %d quantities: median %.4f, largest %.4f (%s), main largest %.4f (%s)", ro, sum(s), median(d[s]),
            max(d[s]), tr[s][which.max(d[s])], max(d[m]), tr[m][which.max(d[m])])
  }, "")
}
clamps <- function(v) if (is.null(v) || all(is.na(v))) "not read" else paste(names(v), v, sep = " ", collapse = ", ")
for (r in names(recs)) {
  g <- recs[[r]]
  cat(sprintf("\n== %s\n", r))
  x0 <- readRDS(g$base); c0 <- cost(x0); Js <- jstar_of(g$jstar)
  xa <- readRDS(g$ruleA); ca <- cost(xa, attempts_of_log(g$drv))
  cat(sprintf("unweighted         rows %8.0f  forward %9.0f  accepted %5d  rejected %4d  longest %5.1f d | J/J* - 1 %+.2e\n",
              c0[["rows"]], c0[["forward"]], c0[["accepted"]], c0[["rejected"]], c0[["longest"]], x0$stand$J / Js - 1))
  cat(sprintf("rule A, 15 d       rows %8.0f  forward %9.0f  accepted %5d  rejected %4d  longest %5.1f d | J/J* - 1 %+.2e | against unweighted: %s\n",
              ca[["rows"]], ca[["forward"]], ca[["accepted"]], ca[["rejected"]], ca[["longest"]], xa$stand$J / Js - 1,
              saving(ca, c0)))
  if (!done(g$bnd)) { cat("bounded: not finished\n"); next }
  x1 <- readRDS(g$bnd); c1 <- cost(x1)
  cat(sprintf("bounded            rows %8.0f  forward %9.0f  accepted %5d  rejected %4d  longest %5.1f d | J/J* - 1 %+.2e\n",
              c1[["rows"]], c1[["forward"]], c1[["accepted"]], c1[["rejected"]], c1[["longest"]], x1$stand$J / Js - 1))
  cat(sprintf("   against unweighted: %s\n   against rule A, 15 d: %s\n", saving(c1, c0), saving(c1, ca)))
  cat(sprintf("soil clamps: forward %s | stand's sweep %s | invader's sweep %s\n", clamps(x1$stand$forward_clamps),
              clamps(x1$stand$swept_clamps), clamps(x1$invader$swept_clamps)))
  for (ro in c("stand", "invader")) {
    v <- x1[[ro]]
    cat(sprintf("gradient, %-7s finite %d of %d; refusal: %s\n", ro, sum(is.finite(v$elasticity)), length(v$elasticity),
                if (is.null(v$refusal) || !any(nzchar(v$refusal))) "none" else substr(paste(v$refusal, collapse = " | "), 1, 200)))
  }
  q0 <- quantities(x0); q1 <- quantities(x1); qa <- quantities(xa)
  n <- intersect(names(q0), names(q1)); d <- abs(q1[n] - q0[n])
  cat(sprintf("moves against the unweighted run (over 0.08: %d, over eps/3: %d):\n", sum(d > 0.08), sum(d > 1 / 3)))
  cat(paste0("   ", by_role(d, n), collapse = "\n"), "\n")
  if (file.exists(g$ref) && !is.null(readRDS(g$ref)$stand$elasticity)) {
    qr <- quantities(readRDS(g$ref)); m <- Reduce(intersect, list(names(qr), names(q0), names(q1), names(qa)))
    d0 <- abs(q0[m] - qr[m]); da <- abs(qa[m] - qr[m]); d1 <- abs(q1[m] - qr[m]); role <- sub(" .*", "", m)
    cat(sprintf("distance from 1e-5 (%s):\n", basename(g$ref)))
    cat(paste0("   unweighted   ", by_role(d0, m), collapse = "\n"), "\n")
    cat(paste0("   rule A, 15 d ", by_role(da, m), collapse = "\n"), "\n")
    cat(paste0("   bounded      ", by_role(d1, m), collapse = "\n"), "\n")
    for (ro in c("resident", "invader")) {
      s <- role == ro
      cat(sprintf("   %-8s bounded farther than the unweighted on %d of %d; C2 (median and largest no larger, largest under eps/3): %s\n",
                  ro, sum(d1[s] > d0[s]), sum(s),
                  if (median(d1[s]) <= median(d0[s]) && max(d1[s]) <= max(d0[s]) && max(d1[s]) < 1 / 3) "pass" else
                    sprintf("FAIL (median %.4f vs %.4f, largest %.4f vs %.4f)", median(d1[s]), median(d0[s]), max(d1[s]), max(d0[s]))))
    }
  } else cat("distance from 1e-5: reference with gradients not available\n")
  w <- readRDS(g$win)
  cat(sprintf("failures: %s\n", if (length(x1$failures)) paste(names(x1$failures), collapse = ", ") else "none"))
  if (!is.null(x1$invader$J)) cat(sprintf("   identical invader J' %.8g (stand J %.8g)\n", x1$invader$J, x1$stand$J))
  skip <- c("stand_run", "stand_gradient", "invader_run", "invader_gradient")
  for (k in setdiff(names(x1$phases), skip)) {
    J1 <- x1$invaders[[k]]$J; J0 <- w$invaders[[k]]$J
    cat(sprintf("   %-9s %s%s\n", k,
                if (!is.null(x1$failures[[k]])) paste("RAISED:", substr(x1$failures[[k]], 1, 150)) else sprintf("J' %-12.6g", J1),
                if (!is.null(J1) && !is.null(J0)) sprintf(" ln J' moves %.4f eps against the unweighted walk", abs(log(J1 / J0)) / eps_lnJ) else ""))
  }
  cat(sprintf("phase seconds: %s\n", paste(sprintf("%s %.0f", names(x1$phases), vapply(x1$phases, `[[`, 0, "secs")), collapse = ", ")))
}

cat("\n== C3 on long drought: the +-5% tolerance nudges, each quantity's larger move, in eps/3\n")
nud <- function(base, nudged) {
  qb <- quantities(readRDS(base)); nq <- lapply(nudged, function(f) quantities(readRDS(f)))
  n <- Reduce(intersect, c(list(names(qb)), lapply(nq, names)))
  list(n = n, d = do.call(pmax, lapply(nq, function(q) abs(q[n] - qb[n]))) * 3)
}
sets <- list(unweighted = list(base = file.path(sc, "ld_3e-5.rds"), nudged = file.path(sc, c("ld_2.85e-5.rds", "ld_3.15e-5.rds"))),
             bounded = list(base = file.path(C, "full/bnd_ld.rds"),
                            nudged = file.path(C, c("full/bnd_ld_2.85e-5.rds", "full/bnd_ld_3.15e-5.rds"))))
for (k in names(sets)) {
  f <- c(sets[[k]]$base, sets[[k]]$nudged)
  if (!all(vapply(f, done, TRUE))) { cat(sprintf("%-10s not available\n", k)); next }
  for (x in f[-1]) {
    y <- readRDS(x)
    cat(sprintf("%-10s %-22s soil clamps on the stand's sweep: %s | gradient finite %d of %d\n", k, basename(x),
                clamps(y$stand$swept_clamps), sum(is.finite(y$stand$elasticity)), length(y$stand$elasticity)))
  }
  v <- nud(sets[[k]]$base, sets[[k]]$nudged); role <- sub(" .*", "", v$n); tr <- sub("^(resident|invader) ", "", v$n)
  for (ro in c("resident", "invader")) {
    s <- role == ro; o <- order(-v$d[s])[1:3]
    cat(sprintf("%-10s %-8s %d quantities: median %.3f, largest %s; over 1: %d -> C3 %s\n", k, ro, sum(s), median(v$d[s]),
                paste(sprintf("%.3f (%s)", v$d[s][o], tr[s][o]), collapse = ", "), sum(v$d[s] > 1),
                if (sum(v$d[s] > 1) == 0) "pass" else "FAIL"))
  }
}
