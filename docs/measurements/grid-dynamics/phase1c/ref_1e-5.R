# Episodic's runs at 3e-5 against plant's own run at 1e-5 (both roles'
# gradients, uniform 108, tied): each quantity's distance from the 1e-5 run, in
# eps. The cap loses accuracy only if its run sits farther than the unweighted.
#
#   Rscript ref_1e-5.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
source(file.path(D, "phase1c/nudge_spread.R"))  # eps, quantities
main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")
ref <- quantities(readRDS(file.path(D, "phase1c/full/epi_1e-5.rds")))
runs <- c("unweighted (pinned)" = file.path(D, "window/full/epi_pin_base.rds"),
          "unweighted, +5% tol" = file.path(WT, "docs/measurements/spot-check/epi_tol.rds"),
          "rule A" = file.path(D, "window/full/epi_pin_rule.rds"),
          "A, cap 15" = file.path(D, "phase1c/full/epi_h15.rds"),
          "A, cap 22" = file.path(D, "phase1c/full/epi_h22.rds"),
          "A, cap 26" = file.path(D, "phase1c/full/epi_h26.rds"),
          "unweighted, cap 15" = file.path(D, "phase1c/full/epi_base_h15.rds"))
d0 <- NULL
for (k in names(runs)) {
  if (!file.exists(runs[[k]]) || is.null(readRDS(runs[[k]])$finished)) next
  q <- quantities(readRDS(runs[[k]])); n <- intersect(names(ref), names(q))
  d <- abs(q[n] - ref[n]); role <- sub(" .*", "", n); tr <- sub("^(resident|invader) ", "", n)
  if (is.null(d0)) d0 <- d
  for (ro in c("resident", "invader")) {
    s <- role == ro; m <- s & tr %in% main
    farther <- if (k == names(runs)[1]) "" else sprintf(" | farther than the unweighted on %d of %d, median excess %+.4f",
                                                          sum(d[s] > d0[n][s]), sum(s), median(d[s] - d0[n][s]))
    cat(sprintf("%-20s %-8s distance from 1e-5: median %.4f, largest %.4f (%s), main largest %.4f (%s), ln J %.4f%s\n",
                k, ro, median(d[s]), max(d[s]), tr[s][which.max(d[s])], max(d[m]), tr[m][which.max(d[m])],
                d[paste(ro, "ln J")], farther))
  }
}
