# The founders' window at its finest measured level: |d| by birth date, all map runs.
source("/home/user/plant-dev/harness/schedule/anyscore.R")
for (case in commandArgs(TRUE)) { cd <- prepare(case); P <- cd$P; P <- P[P$mid < cd$b1, ]; P <- P[order(P$h, P$mid), ]
  hmin <- min(P$h); Q <- P[abs(P$h - hmin) < 1e-6, ]; d <- Q$m / (6 * Q$h^3) / 0.025
  cat(sprintf("%-13s b1 %.2f, panels at h = %.0f d: %s\n", case, cd$b1, hmin * 365, paste(sprintf("%.2f:%+.1f", Q$mid, d), collapse = " "))) }
