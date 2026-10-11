# For each creation-window edge on episodic, the open sliver: the distance from
# the edge to the nearest node on the open side, inside the interval that
# straddles the edge, on pA, pA2, pA4 and on u108, u215, u429.
P2 <- "../placed2/runs"; LAD <- "../../node_rule/ladder/runs"
cr <- readRDS(file.path(P2, "pA4_episodic.rds"))$stand$creation
open <- cr$rate > 0.01; r <- rle(open); e <- cumsum(r$lengths)
edges <- data.frame(t = cr$end[e][-length(e)], kind = ifelse(r$values[-length(r$values)], "closing", "opening"))
edges <- subset(edges, t > 2 & t < 20)
cat(nrow(edges), "edges in 2 < b < 20\n")
sched <- list(pA = readRDS("../placed2/sched/pA_episodic.rds"), pA2 = readRDS("../placed2/sched/pA_episodic_x2.rds"),
              pA4 = readRDS("../placed2/sched/pA_episodic_x4.rds"),
              u108 = seq(0, 107 * 40 / 108, length.out = 108), u215 = seq(0, 214 * 40 / 215, length.out = 215),
              u429 = seq(0, 428 * 40 / 429, length.out = 429))
out <- sapply(sched, function(s) {
  sapply(seq_len(nrow(edges)), function(i) {
    t <- edges$t[i]; L <- max(s[s <= t]); R <- min(s[s > t]); h <- R - L
    sl <- if (edges$kind[i] == "opening") R - t else t - L   # open part of the interval
    sl / h })
})
rownames(out) <- sprintf("%-7s %6.3f", edges$kind, edges$t)
cat("open sliver as a fraction of the straddling interval:\n"); print(round(out, 3))
days <- sapply(sched, function(s) sapply(edges$t, function(t) { L <- max(s[s <= t]); R <- min(s[s > t]); 365 * (R - L) }))
cat("\nstraddling interval width (days), median by schedule:\n"); print(round(apply(days, 2, median), 1))
