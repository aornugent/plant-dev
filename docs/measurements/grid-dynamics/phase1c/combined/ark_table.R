# The implicit soil chain in plant (lib_ark): arm A, arkc (METHOD=ark,
# WEIGHT_SOIL=100) with the 15-day cap; arm B, arm A plus rule A's weight and
# each state's weight at most 100. Per record, against plant's unweighted
# Cash-Karp run and the bounded combined Cash-Karp run: cost, J's error, the
# soil's clamp tallies, gradients, both roles' moves and distance from 1e-5 in
# eps, and every walk; then C3, arm A's +-5% tolerance nudges on long drought.
#
#   Rscript ark_table.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
C <- file.path(D, "phase1c/combined")
source(file.path(D, "phase1c/nudge_spread.R"))  # eps, eps_of, quantities
eps_lnJ <- eps$eps[eps$role == "resident" & eps$trait == "ln J"]
main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")
sc <- file.path(WT, "docs/measurements/spot-check")
recs <- list(
  "long-drought" = list(base = file.path(sc, "ld_3e-5.rds"), bnd = file.path(C, "full/bnd_ld.rds"),
                        A = file.path(C, "full/arkA_ld.rds"), B = file.path(C, "full/arkB_ld.rds"),
                        ref = file.path(WT, "docs/measurements/nudges/ld_1e-5.rds"),
                        win = file.path(D, "window/runs/win_long-drought_u108.rds"), jstar = 12.6687135),
  "long-wet" = list(base = file.path(sc, "wet_base.rds"), bnd = file.path(C, "full/bnd_wet.rds"),
                    A = file.path(C, "full/arkA_wet.rds"), B = file.path(C, "full/arkB_wet.rds"),
                    ref = file.path(C, "full/wet_1e-5.rds"),
                    win = file.path(D, "window/runs/win_long-wet_u108.rds"), jstar = file.path(D, "window/ref/wet_1e-8_abs.rds")),
  episodic = list(base = file.path(sc, "epi_base.rds"), bnd = file.path(C, "full/bnd_epi.rds"),
                  A = file.path(C, "full/arkA_epi.rds"), B = file.path(C, "full/arkB_epi.rds"),
                  ref = file.path(D, "phase1c/full/epi_1e-5.rds"),
                  win = file.path(D, "window/runs/win_episodic_u108.rds"), jstar = file.path(D, "window/ref/epi_1e-8_abs.rds")))
arm_name <- c(A = "arm A (arkc, 15 d)", B = "arm B (A + rule A, max 100)")
done <- function(f) file.exists(f) && !is.null(readRDS(f)$finished)
jstar_of <- function(j) if (is.numeric(j)) j else readRDS(j)$stand$J
rows_of <- function(x) sum(as.numeric(findInterval(head(x$stand$times, -1), sort(x$node_times))))
cost <- function(x) {
  a <- x$stand$attempts; ms <- rows_of(x)
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
    if (!any(s)) return(sprintf("%-8s no finite quantities", ro))
    sprintf("%-8s %d quantities: median %.4f, largest %.4f (%s), main largest %.4f (%s)", ro, sum(s), median(d[s]),
            max(d[s]), tr[s][which.max(d[s])], max(d[m]), tr[m][which.max(d[m])])
  }, "")
}
clamps <- function(v) if (is.null(v) || all(is.na(v))) "not read" else paste(names(v), v, sep = " ", collapse = ", ")
line <- function(label, x, cc, Js) cat(sprintf("%-28s rows %8.0f  forward %9.0f  accepted %5d  rejected %4d  longest %5.1f d | J/J* - 1 %+.2e\n",
                                               label, cc[["rows"]], cc[["forward"]], cc[["accepted"]], cc[["rejected"]], cc[["longest"]],
                                               x$stand$J / Js - 1))
for (r in names(recs)) {
  g <- recs[[r]]
  cat(sprintf("\n== %s\n", r))
  Js <- jstar_of(g$jstar)
  x0 <- readRDS(g$base); c0 <- cost(x0); line("unweighted Cash-Karp", x0, c0, Js)
  xb <- readRDS(g$bnd); cb <- cost(xb); line("bounded combined Cash-Karp", xb, cb, Js)
  q0 <- quantities(x0); qb <- quantities(xb)
  qr <- if (file.exists(g$ref)) quantities(readRDS(g$ref)) else NULL
  w <- readRDS(g$win)
  for (arm in c("A", "B")) {
    f <- g[[arm]]
    if (!file.exists(f)) { cat(sprintf("%s: not run\n", arm_name[[arm]])); next }
    x1 <- readRDS(f)
    if (is.null(x1$stand$times)) { cat(sprintf("%s: the stand did not run: %s\n", arm_name[[arm]],
                                               paste(unlist(x1$failures), collapse = " | "))); next }
    c1 <- cost(x1)
    line(arm_name[[arm]], x1, c1, Js)
    cat(sprintf("   against unweighted Cash-Karp: %s\n   against bounded combined Cash-Karp: %s\n", saving(c1, c0), saving(c1, cb)))
    if (!done(f)) cat("   (still running or killed: later phases missing)\n")
    cat(sprintf("   soil clamps: forward %s | stand's sweep %s | invader's sweep %s\n", clamps(x1$stand$forward_clamps),
                clamps(x1$stand$swept_clamps), clamps(x1$invader$swept_clamps)))
    for (ro in c("stand", "invader")) {
      v <- x1[[ro]]
      if (is.null(v$elasticity)) { cat(sprintf("   gradient, %-7s not computed\n", ro)); next }
      cat(sprintf("   gradient, %-7s finite %d of %d; refusal: %s\n", ro, sum(is.finite(v$elasticity)), length(v$elasticity),
                  if (is.null(v$refusal) || !any(nzchar(v$refusal))) "none" else substr(paste(v$refusal, collapse = " | "), 1, 200)))
    }
    q1 <- quantities(x1); n <- intersect(names(q0), names(q1)); d <- abs(q1[n] - q0[n])
    cat(sprintf("   moves against the unweighted run (over 0.08: %d, over eps/3: %d):\n", sum(d > 0.08), sum(d > 1 / 3)))
    cat(paste0("      ", by_role(d, n), collapse = "\n"), "\n")
    if (!is.null(qr)) {
      m <- Reduce(intersect, list(names(qr), names(q0), names(qb), names(q1)))
      d0 <- abs(q0[m] - qr[m]); db <- abs(qb[m] - qr[m]); d1 <- abs(q1[m] - qr[m]); role <- sub(" .*", "", m)
      cat(sprintf("   distance from 1e-5 (%s):\n", basename(g$ref)))
      if (arm == "A") {
        cat(paste0("      unweighted CK  ", by_role(d0, m), collapse = "\n"), "\n")
        cat(paste0("      bounded CK     ", by_role(db, m), collapse = "\n"), "\n")
      }
      cat(paste0("      ", sprintf("%-14s ", paste("arm", arm)), by_role(d1, m), collapse = "\n"), "\n")
      for (ro in c("resident", "invader")) {
        s <- role == ro
        if (!any(s)) next
        cat(sprintf("      %-8s arm %s farther than the unweighted CK on %d of %d; C2: %s\n", ro, arm, sum(d1[s] > d0[s]), sum(s),
                    if (median(d1[s]) <= median(d0[s]) && max(d1[s]) <= max(d0[s]) && max(d1[s]) < 1 / 3) "pass" else
                      sprintf("FAIL (median %.4f vs %.4f, largest %.4f vs %.4f)", median(d1[s]), median(d0[s]), max(d1[s]), max(d0[s]))))
      }
    }
    cat(sprintf("   failures: %s\n", if (length(x1$failures)) paste(names(x1$failures), substr(unlist(x1$failures), 1, 160), sep = ": ", collapse = " | ") else "none"))
    if (!is.null(x1$invader$J)) cat(sprintf("      identical invader J' %.8g (stand J %.8g)\n", x1$invader$J, x1$stand$J))
    skip <- c("stand_run", "stand_gradient", "invader_run", "invader_gradient")
    for (k in setdiff(names(x1$phases), skip)) {
      J1 <- x1$invaders[[k]]$J; J0 <- w$invaders[[k]]$J
      cat(sprintf("      %-9s %s%s\n", k,
                  if (!is.null(x1$failures[[k]])) paste("RAISED:", substr(x1$failures[[k]], 1, 150)) else sprintf("J' %-12.6g", J1),
                  if (!is.null(J1) && !is.null(J0)) sprintf(" ln J' moves %.4f eps against the unweighted walk", abs(log(J1 / J0)) / eps_lnJ) else ""))
    }
    cat(sprintf("   phase seconds: %s\n", paste(sprintf("%s %.0f", names(x1$phases), vapply(x1$phases, `[[`, 0, "secs")), collapse = ", ")))
  }
}

cat("\n== C3 on long drought: arm A's +-5% tolerance nudges, each quantity's larger move, in eps/3\n")
nud <- function(base, nudged) {
  qb <- quantities(readRDS(base)); nq <- lapply(nudged, function(f) quantities(readRDS(f)))
  n <- Reduce(intersect, c(list(names(qb)), lapply(nq, names)))
  list(n = n, d = do.call(pmax, lapply(nq, function(q) abs(q[n] - qb[n]))) * 3)
}
sets <- list("unweighted CK" = list(base = file.path(sc, "ld_3e-5.rds"), nudged = file.path(sc, c("ld_2.85e-5.rds", "ld_3.15e-5.rds"))),
             "arm A" = list(base = file.path(C, "full/arkA_ld.rds"),
                            nudged = file.path(C, c("full/arkA_ld_2.85e-5.rds", "full/arkA_ld_3.15e-5.rds"))))
for (k in names(sets)) {
  f <- c(sets[[k]]$base, sets[[k]]$nudged)
  if (!all(vapply(f, done, TRUE))) { cat(sprintf("%-13s not available\n", k)); next }
  for (x in f[-1]) {
    y <- readRDS(x)
    cat(sprintf("%-13s %-22s J %.9f | soil clamps on the stand's sweep: %s | gradient finite %d of %d\n", k, basename(x), y$stand$J,
                clamps(y$stand$swept_clamps), sum(is.finite(y$stand$elasticity)), length(y$stand$elasticity)))
  }
  v <- nud(sets[[k]]$base, sets[[k]]$nudged); role <- sub(" .*", "", v$n); tr <- sub("^(resident|invader) ", "", v$n)
  for (ro in c("resident", "invader")) {
    s <- role == ro; o <- order(-v$d[s])[1:min(3, sum(s))]
    cat(sprintf("%-13s %-8s %d quantities: median %.3f, largest %s; over 1: %d -> C3 %s\n", k, ro, sum(s), median(v$d[s]),
                paste(sprintf("%.3f (%s)", v$d[s][o], tr[s][o]), collapse = ", "), sum(v$d[s] > 1),
                if (sum(v$d[s] > 1) == 0) "pass" else "FAIL"))
  }
}
