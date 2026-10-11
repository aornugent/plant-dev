# How well a coarse run's creation edges match a fine run's, per kind.
edges <- function(f) { cr <- readRDS(f)$stand$creation; op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths)
  data.frame(t = cr$end[e][-length(e)], kind = ifelse(r$values[-length(r$values)], "shuts", "opens")) }
args <- commandArgs(TRUE); a <- edges(args[1]); b <- edges(args[2])
for (k in c("opens", "shuts")) {
  ta <- a$t[a$kind == k]; tb <- b$t[b$kind == k]
  d <- sapply(tb, function(t) min(abs(ta - t))) * 365
  cat(sprintf("%s: fine %d, coarse %d; nearest coarse edge (days) 50/90/max %.2f / %.2f / %.1f; within 1 day %.0f%%, within 3 days %.0f%%\n",
              k, length(tb), length(ta), median(d), quantile(d, .9), max(d), 100 * mean(d < 1), 100 * mean(d < 3)))
}
