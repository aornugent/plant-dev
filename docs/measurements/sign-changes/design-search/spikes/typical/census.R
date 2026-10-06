# Census of the incumbent's split node steps on long drought (108 uniform, 1e-4
# tied, r = 0): what the typical sign change looks like and how rare the rest is.
# Reads the final build's split log (p21/final2/scan_0.txt) and its run's
# per-node shares of J.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
x <- readLines(file.path(D, "p21/final2/scan_0.txt"))
sp <- read.table(text = grep("^split ", x, value = TRUE), col.names = c(
  "tag", "t", "h", "p", "n", "u1", "u2", "v0", "v1", "inside"))
.libPaths(c(file.path(D, "lib_rr"), .libPaths()))
f <- readRDS(file.path(D, "p21/final2/split_1.rds"))
n <- f$stand$nodes
m <- min(length(n$establishment), length(n$nrr))
pd <- plant::Weibull_Disturbance_Regime(f$setting$lifetime)
w <- n$establishment[1:m] * n$nrr[1:m] * vapply(n$birth[1:m], pd$density, 0)
share <- w / sum(w)
sp$share <- share[sp$p + 1]
eta <- 1e-4
sp$ends_differ <- sign(sp$v0) != sign(sp$v1)
sp$kappa_sec <- abs(sp$v1 - sp$v0) / eta     # h |dP/dt| / eta by the step's secant
cat("node steps split:", nrow(sp), "\n")
cat("by cuts n:\n"); print(table(n = sp$n, ends_differ = sp$ends_differ, inside = sp$inside))
cat(sprintf("steps holding a split: %d of %d\n", length(unique(sp$t)), length(f$stand$times)))
one <- sp$n == 1 & sp$ends_differ
cat(sprintf("single cut, ends of opposite sign: %d (%.2f%%)\n", sum(one), 100 * mean(one)))
cat("kappa (secant) quantiles over single cuts:\n")
print(signif(quantile(sp$kappa_sec[one], c(0, .001, .01, .05, .1, .25, .5, .75, .9, .99, 1)), 3))
for (k in c(1, 3, 10, 30, 100)) cat(sprintf("  kappa < %g: %d node steps, carrying share-weighted %.3g of the sum\n",
  k, sum(sp$kappa_sec[one] < k), sum(sp$share[one][sp$kappa_sec[one] < k]) / sum(sp$share[one])))
cat("u1 of single cuts, deciles:\n"); print(signif(quantile(sp$u1[one], seq(0, 1, .1)), 3))
cat("h (days) at single cuts:\n"); print(signif(quantile(sp$h[one] * 365, c(.05, .25, .5, .75, .95)), 3))
cat("time of the splits: share before t = 25 (count):", mean(sp$t < 25), "\n")
cat("share-weighted (node's share of J) fraction before t = 25:", sum(sp$share[sp$t < 25]) / sum(sp$share), "\n")
cat("down vs up among single cuts:", table(down = sp$v0[one] > 0), "\n")
# weight proxy: (share * h * |dP|) ^2, the staircase variance's scale per crossing
sp$wt <- (sp$share * sp$h * abs(sp$v1 - sp$v0))^2
o <- order(-sp$wt); cs <- cumsum(sp$wt[o]) / sum(sp$wt)
cat(sprintf("node steps holding 50/90/99%% of the share^2 (h dP)^2 proxy: %d, %d, %d\n",
            which(cs >= .5)[1], which(cs >= .9)[1], which(cs >= .99)[1]))
cat("of the top 500 by proxy: single cut ends differ:", mean(one[o[1:500]]), " before t=25:", mean(sp$t[o[1:500]] < 25), "\n")
cat("pairs and other non-single: \n")
np <- sp[!one, ]
print(table(n = np$n, ends_differ = np$ends_differ))
cat(sprintf("non-single node steps: %d, share-weighted proxy fraction %.4f; in %d distinct steps\n",
            nrow(np), sum(np$wt) / sum(sp$wt), length(unique(np$t))))
cat("non-single: their nodes' shares (top):\n"); print(head(sort(tapply(np$share, np$p + 1, `[`, 1), decreasing = TRUE), 8))
cat("non-single: u1, u2 quantiles; dip width u2-u1:\n")
pr <- np[np$n == 2, ]
print(signif(quantile(pr$u1, c(0, .1, .5, .9, 1)), 3)); print(signif(quantile(pr$u2 - pr$u1, c(0, .1, .5, .9, 1)), 3))
cat("non-single: day of year at their steps (top days):\n")
print(head(sort(table(round(np$t * 365)), decreasing = TRUE), 12))
saveRDS(sp, "census.rds")
