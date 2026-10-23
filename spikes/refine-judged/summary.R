# Tables for the README from score.R's results.
#   Rscript spikes/refine-judged/summary.R RESULTS.rds
res <- readRDS(commandArgs(TRUE)[1])
grp <- function(n) ifelse(n == "lnJ", "lnJ", ifelse(startsWith(n, "g."), "g", "elasticity"))
worst <- function(s, g) { i <- grp(names(s$err)) == g; sprintf("%.2f", max(abs(s$err[i]))) }
miss <- function(s, g) { i <- grp(names(s$err)) == g; sum(abs(s$err[i]) > s$bound[i]) }
cat("| case | scale | set | status | level | passes | nodes | runs | CPU min | wall min | lnJ err | elast. err | g err | uncovered (elast./g) |\n")
cat("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|\n")
for (s in res) {
  case <- sub("@.*", "", s$case); scale <- if (grepl("@", s$case)) sub(".*@", "", s$case) else "1"
  cat(sprintf("| %s | %s | %s | %s | %d | %d | %d | %d | %.1f | %.1f | %s | %s | %s | %d / %d |\n", case, scale,
              if (s$set == "A") "lnJ+elast." else "lnJ+g", s$status, s$level, s$passes, s$nodes, s$runs,
              s$cpu / 60, s$wall / 60, worst(s, "lnJ"), worst(s, "elasticity"), worst(s, "g"),
              miss(s, "elasticity"), miss(s, "g")))
}
# The certificate on the level-0 replay (or the last doubled pair), per group: how much of the run's
# true error the estimate reads (least-squares slope of e on the error), their correlation, and the
# bound's coverage of the corrected answer. Set B only: A has the same estimates on the same runs.
cat("\n| case | scale | group | worst run err | read (slope) | cor | covered |\n|---|---|---|---|---|---|---|\n")
for (s in res) if (s$set == "B") for (g in c("lnJ", "elasticity", "g")) {
  i <- grp(names(s$err)) == g; e <- s$estimate[i]; r <- s$raw[i]
  cat(sprintf("| %s | %s | %s | %.2f | %.2f | %s | %d/%d |\n", sub("@.*", "", s$case),
              if (grepl("@", s$case)) sub(".*@", "", s$case) else "1", g, max(abs(r)), sum(e * r) / sum(r^2),
              if (sum(i) > 2) sprintf("%.2f", cor(e, r)) else "-", sum(abs(s$err[i]) <= s$bound[i]), sum(i)))
}
cat("\nReference self-move (u429 - u215)/3, worst per group, in eps:\n")
for (s in res) if (s$set == "A" && !grepl("@", s$case)) cat(sprintf("- %s: lnJ %.2f, elasticities %.2f, g %.2f\n", s$case,
  max(abs(s$ref_move[grp(names(s$err)) == "lnJ"])), max(abs(s$ref_move[grp(names(s$err)) == "elasticity"])),
  max(abs(s$ref_move[grp(names(s$err)) == "g"]))))
