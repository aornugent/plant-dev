.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
source("/home/user/plant-dev/harness/node_parts.R")
Q <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/placed2/runs"
for (cs in list(c("th0","episodic"), c("th0","dry"), c("th0","long-wet"), c("lma125","episodic"))) {
  tag <- cs[1]; rec <- cs[2]
  n <- lapply(c("", "2", "4"), function(L) nodes_of(readRDS(file.path(Q, sprintf("m_%s%s_%s.rds", tag, L, rec)))))
  mv <- function(a, b) { pm <- panel_moves(a, b); J <- sum(a$w * a$offspring); (pm$field + pm$establishment + pm$interpolation) / J }
  m1 <- mv(n[[1]], n[[2]]); m2 <- mv(n[[2]], n[[3]])
  br <- c(0, 0.1, 0.25, 0.5, 1, 2, 4, 10, 41)
  g1 <- tapply(m1, cut(n[[1]]$birth, br, right = FALSE), sum); g2 <- tapply(m2, cut(n[[2]]$birth, br, right = FALSE), sum)
  c1 <- table(cut(n[[1]]$birth, br, right = FALSE)); J <- n[[3]]$w * n[[3]]$offspring; jj <- tapply(J, cut(n[[3]]$birth, br, right = FALSE), sum) / sum(J)
  cat(sprintf("\n== %s %s\n", tag, rec)); print(round(rbind(nodesL0 = c1, Jshare = jj, `L0-L1` = g1 * 1e3, `L1-L2` = g2 * 1e3, ratio = g1 / g2), 2))
  cat("L0 founders' nodes:", round(n[[1]]$birth[n[[1]]$birth < 4], 3), "\n")
}
