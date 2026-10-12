# Central-only coarsening of G against the truth from the map on B = bisect(G):
# G's error per interval is 4/3 of B's dropped-midpoint move. Covered = intervals inside
# a dropped node's panel.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
pe <- function(x) { b <- nd(x); j <- x$dropped; data.frame(t = x$node_times[j], e = own_drop(b, j) / sum(b$w * b$offspring) + colSums(x$light + x$soil) / x$stand$J) }
for (cs in list(c("cen_u108e_episodic", "hier_u108e_episodic_p1"), c("cen_dy_dry", "hier_dy_dry_p1"))) {
  xc <- run(cs[1]); xb <- run(cs[2]); if (is.null(xc$soil)) next
  g <- xc$node_times; j <- xc$dropped; a <- pe(xc); bb <- pe(xb)
  lo <- g[j - 1]; hi <- g[j + 1]; l <- (g[j] - lo) / (hi - lo); f <- (l^3 + (1 - l)^3) / (3 * l * (1 - l))
  tr_cov <- 4 / 3 * sum(bb$e[sapply(bb$t, function(t) any(t > lo & t < hi))]); tr_all <- 4 / 3 * sum(bb$e)
  cat(sprintf("%s: G's error (truth) %+.3f eps, of which covered panels %+.3f | estimate on covered panels %+.3f (plain e/3 %+.3f)\n",
    cs[1], tr_all / .025, tr_cov / .025, sum(a$e * f) / .025, sum(a$e) / 3 / .025)) }
