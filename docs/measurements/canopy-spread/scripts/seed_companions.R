# Per long-drought seed, the invader's lma elasticity on lumped and spread uniform
# ladders: each rung's error against a reference (the spread ladder's u215 + u429
# extrapolation; for seed 31 also the graded one), and the companion's estimate over
# the error at u215 and u429. Usage: Rscript seed_companions.R
runs <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb/runs"
cg <- "/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba/docs/measurements/creation-grid"
el <- function(f) { if (!file.exists(f)) return(NA); x <- readRDS(f); J <- vapply(x$invader, `[[`, 0, "J"); (J[["plus"]] - J[["minus"]]) / (2 * x$u * x$stand$J) }
lad <- list(
  "31" = list(lumped = file.path(cg, c("inv_u108.rds", "inv_u215.rds", "inv_u429.rds")),
              spread = file.path(runs, c("spread8_u108.rds", "spread8_u215.rds", "spread8_u429.rds"))),
  "101" = list(lumped = file.path(runs, sprintf("seed101_lumped_%s.rds", c("u108", "u215", "u429"))),
               spread = file.path(runs, sprintf("seed101_spread_%s.rds", c("u108", "u215", "u429")))),
  "103" = list(lumped = file.path(runs, sprintf("seed103_lumped_%s.rds", c("u108", "u215", "u429"))),
               spread = file.path(runs, sprintf("seed103_spread_%s.rds", c("u108", "u215", "u429")))))
graded31 <- -27.0415 + (-27.0415 + 27.0481) / 3 + (-27.0520 + 27.0481)
for (s in names(lad)) {
  e <- lapply(lad[[s]], function(f) vapply(f, el, 0))
  ref <- e$spread[3] + (e$spread[3] - e$spread[2]) / 3
  refs <- c(own = unname(ref), graded = if (s == "31") graded31 else NA)
  for (rn in names(refs)) {
    r <- refs[[rn]]; if (is.na(r)) next
    cat(sprintf("seed %s, reference %s %.4f\n", s, rn, r))
    for (sc in names(e)) {
      v <- e[[sc]]; err <- v - r
      comp <- c(NA, abs(v[1] - v[2]) / 3 / abs(err[2]), abs(v[2] - v[3]) / 3 / abs(err[3]))
      ratio <- (v[1] - v[2]) / (v[2] - v[3])
      cat(sprintf("  %-6s el %s | error/eps %s | companion %s | ratio %.2f\n", sc,
                  paste(sprintf("%.4f", v), collapse = " "), paste(sprintf("%+.3f", err / 0.2), collapse = " "),
                  paste(sprintf("%.2f", comp[-1]), collapse = " "), ratio))
    }
  }
}
