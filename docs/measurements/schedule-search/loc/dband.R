source("/home/user/plant-dev/harness/schedule/anyscore.R")
for (case in commandArgs(TRUE)) { cd <- prepare(case); x <- run(sprintf("loc_G0_%s", case)); S <- x$node_times; j <- x$dropped; b <- nd(x)
  m <- own_drop(b, j) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J
  h <- (S[j + 1] - S[j - 1]) / 2; d <- abs(m) / (6 * h^3) / 0.025; g <- cut(S[j], c(0, cd$b1, 5, 10, 15, 20, 25, 40))
  cat(sprintf("%-13s median |d| (eps per y^3) by band: %s | sign negative %.0f%%\n", case, paste(sprintf("%s %.1f", levels(g), tapply(d, g, median)), collapse = "  "), 100 * mean(m < 0))) }
