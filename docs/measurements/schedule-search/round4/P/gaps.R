# Each shut gap of a committed run (both its edges nodes): length, ln nrr across it, and the
# spell after it: how far the per-recruit fate moves across a gap.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
for (cs in c("dry", "episodic", "long-drought", "dry-flat")) { x <- rd_run("a09", "c", cs); n <- x$stand$nodes; b <- n$birth; p <- pilot_of(cs)
  m <- length(b); mid <- (b[-1] + b[-m]) / 2; shut <- p$shut(mid) > 0.5; e <- is_edge(b, p$edges)
  i <- which(shut & e[-m] & e[-1] & b[-m] < 25); len <- (b[i + 1] - b[i]) * 365; dl <- log(n$nrr[i + 1] / n$nrr[i])
  cat(sprintf("%-13s gaps %3d | length d: med %.1f max %.0f, total %.0f d | dln nrr across: med %.3f, |.|>0.1: %d, by length <10d med|.| %.3f, 10-60d %.3f, >60d %.3f (n %d) | slope per day med %.4f\n", cs, length(i), median(len), max(len), sum(len),
    median(dl), sum(abs(dl) > 0.1), median(abs(dl[len < 10])), median(abs(dl[len >= 10 & len < 60])), median(abs(dl[len >= 60])), sum(len >= 60), median(dl / len))) }
