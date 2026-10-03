# The combined setting (soil x10, rule A's weight, a 15-day cap) against plant's
# own unweighted runs, per record: cost, J's error, both roles' moves in eps, the
# distance from the 1e-5 reference, and every walk; then the combined setting's
# +-5% tolerance nudges on long drought against the unweighted ones.
#
#   Rscript combined_table.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
C <- file.path(D, "phase1c/combined")
source(file.path(D, "phase1c/nudge_spread.R"))  # eps, eps_of, quantities
eps_lnJ <- eps$eps[eps$role == "resident" & eps$trait == "ln J"]
main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")
sc <- file.path(WT, "docs/measurements/spot-check")
recs <- list(
  "long-drought" = list(base = file.path(sc, "ld_3e-5.rds"), comb = file.path(C, "full/comb_ld.rds"),
                        ref = file.path(WT, "docs/measurements/nudges/ld_1e-5.rds"),
                        win = file.path(D, "window/runs/win_long-drought_u108.rds"), jstar = 12.6687135),
  "long-wet" = list(base = file.path(sc, "wet_base.rds"), comb = file.path(C, "full/comb_wet.rds"),
                    ref = file.path(C, "full/wet_1e-5.rds"), ref_forward = file.path(C, "full/wet_1e-5_forward.rds"),
                    win = file.path(D, "window/runs/win_long-wet_u108.rds"),
                    jstar = file.path(D, "window/ref/wet_1e-8_abs.rds")),
  episodic = list(base = file.path(sc, "epi_base.rds"), comb = file.path(C, "full/comb_epi.rds"),
                  ref = file.path(D, "phase1c/full/epi_1e-5.rds"), win = file.path(D, "window/runs/win_episodic_u108.rds"),
                  jstar = file.path(D, "window/ref/epi_1e-8_abs.rds")))
done <- function(f) file.exists(f) && !is.null(readRDS(f)$finished)
jstar_of <- function(j) if (is.numeric(j)) j else readRDS(j)$stand$J
# Rows: the members on each accepted step; forward: rows times attempts over
# accepted steps (harness/window_test.R's cost_of).
cost <- function(x) {
  ms <- sum(as.numeric(findInterval(head(x$stand$times, -1), sort(x$node_times))))
  a <- x$stand$attempts
  c(rows = ms, forward = ms * (a[["accepted"]] + a[["rejected_inaccurate"]] + a[["rejected_thrown"]]) / a[["accepted"]],
    accepted = a[["accepted"]], rejected = a[["rejected_inaccurate"]] + a[["rejected_thrown"]],
    longest = max(diff(x$stand$times)) * 365)
}
by_role <- function(d, n) {
  role <- sub(" .*", "", n); tr <- sub("^(resident|invader) ", "", n)
  vapply(c("resident", "invader"), function(ro) {
    s <- role == ro; m <- s & tr %in% main
    sprintf("%-8s median %.4f, largest %.4f (%s), main largest %.4f (%s)", ro, median(d[s]), max(d[s]),
            tr[s][which.max(d[s])], max(d[m]), tr[m][which.max(d[m])])
  }, "")
}
for (r in names(recs)) {
  g <- recs[[r]]
  cat(sprintf("\n== %s\n", r))
  x0 <- readRDS(g$base); c0 <- cost(x0); Js <- jstar_of(g$jstar)
  cat(sprintf("unweighted   rows %8.0f  forward %9.0f  accepted %5d  rejected %4d  longest %5.1f d | J %.9f, J/J* - 1 %+.2e\n",
              c0[["rows"]], c0[["forward"]], c0[["accepted"]], c0[["rejected"]], c0[["longest"]], x0$stand$J, x0$stand$J / Js - 1))
  if (!done(g$comb)) { cat("combined: not finished\n"); next }
  x1 <- readRDS(g$comb); c1 <- cost(x1)
  sv <- 1 - c1[c("rows", "forward")] / c0[c("rows", "forward")]
  cat(sprintf("combined     rows %8.0f  forward %9.0f  accepted %5d  rejected %4d  longest %5.1f d | J %.9f, J/J* - 1 %+.2e | saves rows %.1f%%, forward %.1f%%, a gradient run %.1f%%\n",
              c1[["rows"]], c1[["forward"]], c1[["accepted"]], c1[["rejected"]], c1[["longest"]], x1$stand$J, x1$stand$J / Js - 1,
              100 * sv[["rows"]], 100 * sv[["forward"]],
              100 * (1 - (c1[["forward"]] / c0[["forward"]] + 6 * c1[["rows"]] / c0[["rows"]]) / 7)))
  for (ro in c("stand", "invader")) {
    v <- x1[[ro]]
    cat(sprintf("gradient, %-7s finite %d of %d; refusal: %s\n", ro, sum(is.finite(v$elasticity)), length(v$elasticity),
                if (is.null(v$refusal) || !any(nzchar(v$refusal))) "none" else substr(paste(v$refusal, collapse = " | "), 1, 200)))
  }
  q0 <- quantities(x0); q1 <- quantities(x1); n <- intersect(names(q0), names(q1))
  d <- abs(q1[n] - q0[n])
  cat(sprintf("moves against the unweighted run, %d quantities (over 0.08: %d, over eps/3: %d):\n", length(n),
              sum(d > 0.08), sum(d > 1 / 3)))
  cat(paste0("   ", by_role(d, n), collapse = "\n"), "\n")
  if (file.exists(g$ref) && !is.null(readRDS(g$ref)$stand$elasticity)) {
    qr <- quantities(readRDS(g$ref)); m <- Reduce(intersect, list(names(qr), names(q0), names(q1)))
    d0 <- abs(q0[m] - qr[m]); d1 <- abs(q1[m] - qr[m]); role <- sub(" .*", "", m)
    cat(sprintf("distance from 1e-5 (%s):\n", basename(g$ref)))
    cat(paste0("   unweighted ", by_role(d0, m), collapse = "\n"), "\n")
    cat(paste0("   combined   ", by_role(d1, m), collapse = "\n"), "\n")
    for (ro in c("resident", "invader")) {
      s <- role == ro
      cat(sprintf("   %-8s combined farther than the unweighted on %d of %d; largest over eps/3: %s\n", ro,
                  sum(d1[s] > d0[s]), sum(s), if (max(d1[s]) > 1 / 3) "YES" else "no"))
    }
  } else if (file.exists(g$ref_forward)) {
    Jr <- readRDS(g$ref_forward)$stand$J
    cat(sprintf("distance from 1e-5 (%s, forward only): ln J unweighted %.4f, combined %.4f eps\n", basename(g$ref_forward),
                abs(log(x0$stand$J / Jr)) / eps_lnJ, abs(log(x1$stand$J / Jr)) / eps_lnJ))
  } else cat("distance from 1e-5: reference not available\n")
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

cat("\n== R2 on long drought: the +-5% tolerance nudges, each quantity's larger move, in eps/3\n")
nud <- function(base, nudged) {
  qb <- quantities(readRDS(base)); nq <- lapply(nudged, function(f) quantities(readRDS(f)))
  n <- Reduce(intersect, c(list(names(qb)), lapply(nq, names)))
  list(n = n, d = do.call(pmax, lapply(nq, function(q) abs(q[n] - qb[n]))) * 3)
}
sets <- list(unweighted = list(base = file.path(sc, "ld_3e-5.rds"), nudged = file.path(sc, c("ld_2.85e-5.rds", "ld_3.15e-5.rds"))),
             combined = list(base = file.path(C, "full/comb_ld.rds"),
                             nudged = file.path(C, c("full/comb_ld_2.85e-5.rds", "full/comb_ld_3.15e-5.rds"))))
for (k in names(sets)) {
  f <- c(sets[[k]]$base, sets[[k]]$nudged)
  if (!all(vapply(f, function(x) file.exists(x) && !is.null(readRDS(x)$stand$elasticity) && !is.null(readRDS(x)$invader$elasticity), TRUE))) {
    cat(sprintf("%-10s not available\n", k)); next
  }
  v <- nud(sets[[k]]$base, sets[[k]]$nudged); role <- sub(" .*", "", v$n); tr <- sub("^(resident|invader) ", "", v$n)
  for (ro in c("resident", "invader")) {
    s <- role == ro; o <- order(-v$d[s])[1:3]
    cat(sprintf("%-10s %-8s median %.3f, largest %s; over 1: %d of %d\n", k, ro, median(v$d[s]),
                paste(sprintf("%.3f (%s)", v$d[s][o], tr[s][o]), collapse = ", "), sum(v$d[s] > 1), sum(s)))
  }
}
