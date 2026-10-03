# Long drought's runs at 3e-5 against the assessment's run at 1e-5 (plant's own
# control, tied, uniform 108; docs/measurements/nudges/ld_1e-5.rds), with that
# run's +-5% nudges (9.5e-6, 1.05e-5) as its own noise: each quantity's distance
# in eps, as ref_1e-5.R scores episodic.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
source(file.path(D, "phase1c/nudge_spread.R"))  # eps, quantities
main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")
nd <- file.path(WT, "docs/measurements/nudges")
x_ref <- readRDS(file.path(nd, "ld_1e-5.rds"))
cat("reference fields:", paste(names(x_ref), collapse = ", "), "\n")
ref <- quantities(x_ref)
cat(sprintf("reference quantities: %d; ln J %.6f\n", length(ref), log(x_ref$stand$J)))
runs <- c("1e-5 nudged to 9.5e-6" = file.path(nd, "ld_9.5e-6.rds"),
          "1e-5 nudged to 1.05e-5" = file.path(nd, "ld_1.05e-5.rds"),
          "unweighted (pinned)" = file.path(D, "window/full/ld_pin_base.rds"),
          "rule A" = file.path(D, "window/full/ld_pin_rule.rds"),
          "A, cap 15" = file.path(D, "phase1c/full/ld_h15.rds"),
          "A, cap 22" = file.path(D, "phase1c/full/ld_h22.rds"))
d0 <- NULL
for (k in names(runs)) {
  if (!file.exists(runs[[k]]) || is.null(readRDS(runs[[k]])$stand$elasticity)) next
  q <- quantities(readRDS(runs[[k]])); n <- intersect(names(ref), names(q))
  d <- abs(q[n] - ref[n]); role <- sub(" .*", "", n); tr <- sub("^(resident|invader) ", "", n)
  if (k == "unweighted (pinned)") d0 <- d
  for (ro in c("resident", "invader")) {
    s <- role == ro; m <- s & tr %in% main
    farther <- if (is.null(d0) || k == "unweighted (pinned)") "" else
      sprintf(" | farther than the unweighted on %d of %d", sum(d[s] > d0[n][s]), sum(s))
    cat(sprintf("%-24s %-8s %d quantities, distance from 1e-5: median %.4f, largest %.4f (%s), main largest %.4f (%s)%s\n",
                k, ro, sum(s), median(d[s]), max(d[s]), tr[s][which.max(d[s])], max(d[m]), tr[m][which.max(d[m])], farther))
  }
}
