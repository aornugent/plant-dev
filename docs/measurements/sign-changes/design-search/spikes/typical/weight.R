# Per node: its share of J and its split node steps. If only nodes above a share
# were treated (the rest plain), how many node steps and how much of the
# share-weighted proxy (share * h * |dP|)^2 would be kept?
sp <- readRDS("census.rds")
by <- aggregate(cbind(n = 1, wt = sp$wt, early = sp$t < 25) ~ p, data = transform(sp, early = as.numeric(t < 25)), FUN = sum)
by$share <- tapply(sp$share, sp$p, `[`, 1)[as.character(by$p)]
by <- by[order(-by$share), ]
by$cum_share <- cumsum(by$share)
by$cum_n <- cumsum(by$n) / sum(by$n)
by$cum_wt <- cumsum(by$wt) / sum(by$wt)
cat("top nodes by share of J (node = p+1):\n")
print(head(transform(by, node = p + 1, share = signif(share, 3), cum_share = signif(cum_share, 4),
                     cum_n = signif(cum_n, 3), cum_wt = signif(cum_wt, 4))[, c("node", "share", "n", "early", "cum_share", "cum_n", "cum_wt")], 25), row.names = FALSE)
for (s in c(1e-2, 3e-3, 1e-3, 1e-4, 1e-5, 1e-6)) {
  k <- by$share >= s
  cat(sprintf("treat nodes with share >= %g: %d nodes, %d node steps (%.1f%%), J share %.5f, proxy kept %.5f\n",
              s, sum(k), sum(by$n[k]), 100 * sum(by$n[k]) / sum(by$n), sum(by$share[k]), sum(by$wt[k]) / sum(by$wt)))
}
# by time: before/after J's window end
for (tc in c(15, 20, 25, 29.3, 32)) {
  k <- sp$t < tc
  cat(sprintf("crossings before t = %g: %d (%.1f%%), proxy kept %.4f\n", tc, sum(k), 100 * mean(k), sum(sp$wt[k]) / sum(sp$wt)))
}
# clustering: node steps per split step
ns <- table(sp$t)
cat("node steps per split step: quantiles\n"); print(quantile(as.vector(ns), c(.1, .25, .5, .75, .9, 1)))
