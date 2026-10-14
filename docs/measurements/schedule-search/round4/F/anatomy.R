# Where a09's committed nodes and rows sit: edges, intervals at the range cap, by band.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
for (cs in ALL) { P <- pair(cs); S <- P$xc$node_times; p <- P$p; ed <- round(p$edges[p$edges <= 25], 10)
  ise <- round(S, 10) %in% ed; lo <- head(S, -1); hi <- S[-1]; w <- hi - lo; open <- p$shut((lo + hi) / 2) < 0.5
  cap <- ifelse(hi <= p$b1 + 1e-9, p$b1 / 12, ifelse(lo < 20, 100 / 365, 280 / 365)); atcap <- open & w > 0.9 * cap
  life <- 39.6 - S; band <- cut(S, c(-1, p$b1, 10, 25, 40))
  sh <- tapply(life, band, sum) / sum(life)
  o <- order(-abs(P$ec))[1:3]
  cat(sprintf("%-12s n %3d edges %3d (%.0f%%) open intervals %3d at >0.9 cap %3d | life share <b1 %.2f b1-10 %.2f 10-25 %.2f >25 %.2f | worst %s | n>0.5eps %d\n",
    cs, length(S), sum(ise), 100 * mean(ise), sum(open), sum(atcap), sh[1], sh[2], sh[3], sh[4],
    paste(sprintf("%s %.2f", P$k[o], P$ec[o]), collapse = ", "), sum(abs(P$ec) > 0.5))) }
