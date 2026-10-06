# How linear is net production across a crossing step? For P = P'(t - t*) +
# P''(t - t*)^2 / 2 the secant zero u_lin = v0 / (v0 - v1) misses the located
# zero u* by about q u*(1 - u*) / 2 with q = P'' h / P'. So q ~ 2 |u* - u_lin| /
# (u*(1 - u*)) reads the curvature of P on the step's scale, which sets how much a
# closed-form kink correction (leading term only) leaves: its next term is q / 2
# of the kink's own error.
sp <- readRDS("census.rds")
one <- sp[sp$n == 1, ]
one$ulin <- one$v0 / (one$v0 - one$v1)
one$q <- 2 * abs(one$u1 - one$ulin) / pmax(one$u1 * (1 - one$u1), 1e-3)
qs <- c(.01, .03, .1, .3, 1, 3)
cat("q = P'' h / P' over single cuts: quantiles\n")
print(signif(quantile(one$q, c(.05, .1, .25, .5, .75, .9, .95)), 3))
for (qq in qs) cat(sprintf("  q < %g: %.1f%% of single cuts, %.1f%% of the share-weighted proxy\n",
  qq, 100 * mean(one$q < qq), 100 * sum(one$wt[one$q < qq]) / sum(one$wt)))
# the proxy-heaviest 300: their q
o <- order(-one$wt)[1:300]
cat("the 300 heaviest by proxy: q quantiles\n"); print(signif(quantile(one$q[o], c(.1, .25, .5, .75, .9)), 3))
