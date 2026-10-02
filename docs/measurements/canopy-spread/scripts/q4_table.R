# Accuracy against cost for the invader's lma elasticity on long drought seed 31:
# lumped and spread, uniform and graded. Error against the graded reference (in
# central-difference terms, as companion.R), in eps = 0.20; member steps (each
# node's accepted steps after its birth) from the committed lumped full run of the
# same schedule; and each pair of nested rungs extrapolated, at the pair's cost.
wt <- "/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba"
runs <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb/runs"
cg <- file.path(wt, "docs/measurements/creation-grid"); sc <- file.path(wt, "docs/measurements/spot-check")
el <- function(x) { J <- vapply(x$invader, `[[`, 0, "J"); (J[["plus"]] - J[["minus"]]) / (2 * x$u * x$stand$J) }
ref <- -27.0415 + (-27.0415 + 27.0481) / 3 + (-27.0520 + 27.0481)
member_steps <- function(x) sum(vapply(x$node_times, function(b) sum(x$stand$times > b), 0))
full <- c(u108 = file.path(sc, "ld_3e-5.rds"), u215 = file.path(sc, "ld_n215.rds"), u429 = file.path(cg, "ld_u429_full.rds"),
          G1 = file.path(cg, "ld_G1_full.rds"), G2 = file.path(cg, "ld_G2_full.rds"), G3 = file.path(cg, "ld_G3_full.rds"))
cost <- vapply(full, function(f) member_steps(readRDS(f)), 0)
files <- list(
  lumped = c(u108 = file.path(cg, "inv_u108.rds"), u215 = file.path(cg, "inv_u215.rds"), u429 = file.path(cg, "inv_u429.rds"),
             G1 = file.path(cg, "inv_ld_G1.rds"), G2 = file.path(cg, "inv_ld_G2.rds"), G3 = file.path(runs, "graded_lumped_ld_G3.rds")),
  spread = c(u108 = file.path(runs, "spread8_u108.rds"), u215 = file.path(runs, "spread8_u215.rds"), u429 = file.path(runs, "spread8_u429.rds"),
             G1 = file.path(runs, "graded_spread_ld_G1.rds"), G2 = file.path(runs, "graded_spread_ld_G2.rds"), G3 = file.path(runs, "graded_spread_ld_G3.rds")))
cat(sprintf("reference %.4f; eps 0.20\n", ref))
for (s in names(files)) {
  e <- vapply(files[[s]], function(f) if (file.exists(f)) el(readRDS(f)) else NA, 0)
  cat(sprintf("\n-- %s\n", s))
  for (g in names(e)) if (!is.na(e[g]))
    cat(sprintf("  %-5s %.4f  error %+.3f eps  member steps %.3g\n", g, e[g], (e[g] - ref) / 0.2, cost[g]))
  pairs <- list(c("u108", "u215"), c("u215", "u429"), c("G1", "G2"), c("G2", "G3"))
  for (p in pairs) if (all(!is.na(e[p]))) {
    x <- e[p[2]] + (e[p[2]] - e[p[1]]) / 3
    cat(sprintf("  %s+%s extrapolated %.4f  error %+.3f eps  companion %.2f  member steps %.3g\n", p[1], p[2], x,
                (x - ref) / 0.2, abs(e[p[1]] - e[p[2]]) / 3 / abs(e[p[2]] - ref), sum(cost[p])))
  }
}
