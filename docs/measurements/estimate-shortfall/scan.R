# Fate along birth date in the founders' window from the dense scans (nodes every
# 1/128 yr): net reproduction, establishment per unit birth date, sign-change counts.
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
source("/home/user/plant-dev/harness/node_parts.R")
Q <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/placed2/runs"
for (nm in c("scan_th0_episodic", "scan_lma125_episodic")) {
  f <- file.path(Q, paste0(nm, ".rds")); if (!file.exists(f)) next; x <- readRDS(f); n <- nodes_of(x)
  s <- x$stand$splits[seq_len(nrow(n))]; k <- which(n$birth <= 3.7)
  b <- n$birth[k]; off <- n$offspring[k]; J <- sum(n$w * n$offspring)
  d2 <- c(NA, diff(off, differences = 2), NA)
  cat(sprintf("\n== %s: J %.5g, %d nodes in [0, 3.7]\n", nm, x$stand$J, length(k)))
  i <- round(seq(1, length(k), length.out = 40))
  print(data.frame(b = round(b[i], 3), off = signif(off[i], 3), wJ = signif(n$w[k][i] / J * 1e3, 3), splits = s[k][i]), row.names = FALSE)
  ch <- which(diff(s[k]) != 0); cat("count changes at b =", round(b[ch], 4), "\n")
  big <- order(-abs(d2 * n$w[k]))[1:10]; cat("largest |w * second difference| at b =", round(sort(b[big]), 4), "\n")
}
