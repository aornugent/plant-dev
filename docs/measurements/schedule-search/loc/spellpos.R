# Does the error per interval rise toward the end of an open spell? From each case's
# G0 map run: |d| (eps per y^3) of every dropped node after b1, by where the node sits
# in its spell (0 at the opening edge, 1 at the closing one) and by days to the closing edge.
source("/home/user/plant-dev/harness/schedule/anyscore.R")
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
for (case in commandArgs(TRUE)) { cd <- prepare(case); pe <- pilot_edges(case); e <- sort(pe$edges)
  x <- run(sprintf("loc_G0_%s", case)); S <- x$node_times; j <- x$dropped; b <- nd(x)
  m <- own_drop(b, j) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J
  h <- (S[j + 1] - S[j - 1]) / 2; d <- abs(m) / (6 * h^3) / 0.025; t <- S[j]
  i <- findInterval(t, e); lo <- ifelse(i >= 1, e[pmax(i, 1)], 0); hi <- ifelse(i < length(e), e[pmin(i + 1, length(e))], 39.6)
  keep <- t > cd$b1 & t < 20 & pe$shut(t) < 0.5 & !(round(t, 10) %in% round(e, 10)) & hi - lo > 2 * h
  pos <- (t - lo) / (hi - lo); toend <- (hi - t) * 365; z <- d[keep] / median(d[keep])
  g <- cut(pos[keep], c(0, 0.25, 0.5, 0.75, 1), include.lowest = TRUE); g2 <- cut(toend[keep], c(0, 30, 60, 120, 1e4))
  cat(sprintf("%-13s n %d | |d|/median by position in spell: %s | by days to closing edge: %s | spearman(pos, d) %.2f\n", case, sum(keep),
    paste(sprintf("%s %.2f", levels(g), tapply(z, g, median)), collapse = " "), paste(sprintf("%s %.2f(%d)", levels(g2), tapply(z, g2, median), as.vector(table(g2))), collapse = " "),
    cor(pos[keep], d[keep], method = "spearman"))) }
