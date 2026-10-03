# Post hoc: each capped run's quantity moves against the record's own +5%
# tolerance nudge at 3e-5 (spot-check <r>_tol at 3.15e-5 against <r>_base, plant's
# own control; long drought's 3.15e-5 and 2.85e-5 against 3e-5), quantity by
# quantity: sizes, how many exceed the nudge's move, and whether the same
# quantities move (Spearman's rank correlation of the two moves).
#
#   Rscript compare_nudge.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
source(file.path(D, "phase1c/nudge_spread.R"))  # eps, quantities
sc <- file.path(WT, "docs/measurements/spot-check")
q_of <- function(f) quantities(readRDS(f))
nudges <- list(
  "long-drought" = list(base = file.path(sc, "ld_3e-5.rds"), nudged = c(file.path(sc, "ld_3.15e-5.rds"), file.path(sc, "ld_2.85e-5.rds"))),
  "long-wet" = list(base = file.path(sc, "wet_base.rds"), nudged = file.path(sc, "wet_tol.rds")),
  episodic = list(base = file.path(sc, "epi_base.rds"), nudged = file.path(sc, "epi_tol.rds")))
runs <- list(
  "long-drought" = c(unweighted = "window/full/ld_pin_base", "rule A" = "window/full/ld_pin_rule",
                     "A, cap 15" = "phase1c/full/ld_h15", "A, cap 22" = "phase1c/full/ld_h22",
                     "unweighted, cap 15" = "phase1c/full/ld_base_h15"),
  "long-wet" = c(unweighted = NA, "rule A" = "phase1c/full/wet_ruleA", "A, cap 15" = "phase1c/full/wet_h15",
                 "unweighted, cap 15" = "phase1c/full/wet_base_h15"),
  episodic = c(unweighted = "window/full/epi_pin_base", "rule A" = "window/full/epi_pin_rule",
               "A, cap 15" = "phase1c/full/epi_h15", "A, cap 22" = "phase1c/full/epi_h22",
               "unweighted, cap 15" = "phase1c/full/epi_base_h15"))
done <- function(f) file.exists(f) && !is.null(readRDS(f)$finished)
for (r in names(runs)) {
  qb <- q_of(nudges[[r]]$base)
  nq <- lapply(nudges[[r]]$nudged, q_of)
  n <- Reduce(intersect, c(list(names(qb)), lapply(nq, names)))
  nud <- do.call(pmax, lapply(nq, function(q) abs(q[n] - qb[n])))
  role <- sub(" .*", "", n)
  cat(sprintf("== %s: the +5%% nudge%s at 3e-5 (plant's own control)\n", r, if (length(nq) > 1) " and -5%" else ""))
  for (ro in c("resident", "invader")) {
    s <- role == ro
    cat(sprintf("   nudge   %-8s median %.4f, largest %.4f (%s), over 0.08: %d\n", ro, median(nud[s]), max(nud[s]),
                sub("^(resident|invader) ", "", n[s][which.max(nud[s])]), sum(nud[s] > 0.08)))
  }
  f0 <- if (is.na(runs[[r]][["unweighted"]])) nudges[[r]]$base else file.path(D, paste0(runs[[r]][["unweighted"]], ".rds"))
  q0 <- q_of(f0)
  for (k in setdiff(names(runs[[r]]), "unweighted")) {
    f <- file.path(D, paste0(runs[[r]][[k]], ".rds"))
    if (!done(f)) next
    q <- q_of(f); m <- intersect(n, names(q))
    d <- abs(q[m] - q0[m]); rm <- sub(" .*", "", m)
    for (ro in c("resident", "invader")) {
      s <- rm == ro
      cat(sprintf("   %-18s %-8s median %.4f, largest %.4f (%s), over 0.08: %d | exceeds the nudge's move on %d of %d | rank correlation with it %+.2f\n",
                  k, ro, median(d[s]), max(d[s]), sub("^(resident|invader) ", "", m[s][which.max(d[s])]), sum(d[s] > 0.08),
                  sum(d[s] > nud[m][s]), sum(s), cor(d[s], nud[m][s], method = "spearman")))
    }
  }
}
