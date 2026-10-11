# Placed ladder pA -> pA2 -> pA4 (episodic, nested): ln J and the own part of
# each coarsening, by panel class.
source("../adjmap/lib.R")
P2 <- file.path(D, "schedtest/placed2/runs")
lv <- c("pA", "pA2", "pA4")
x <- lapply(lv, function(k) readRDS(file.path(P2, paste0(k, "_episodic.rds"))))
names(x) <- lv
lnJ <- sapply(x, function(r) log(r$stand$J)); cat("ln J:", lnJ, "\nmoves pA-pA2, pA2-pA4:", diff(-lnJ), " ratio", diff(lnJ)[1] / diff(lnJ)[2], "\n")
el <- sapply(x, function(r) r$stand$elasticity); 
d1 <- el[, 1] - el[, 2]; d2 <- el[, 2] - el[, 3]
cat("resident elasticity move ratios, quantiles:", round(quantile((d1 / d2)[abs(d2) > 1e-4], c(.1, .25, .5, .75, .9)), 2), "\n")
for (k in c("pA2", "pA4")) {
  r <- x[[k]]; b <- nd(r); n <- nrow(b); j <- seq(2, n - 1, by = 2)
  full <- quantile(b$w[b$w > 0], 0.9) * 0 + NA
  # local full weight: an interval's count over its width at the open rate
  wid <- c(diff(b$birth), NA)
  JnP <- sum(b$w * b$offspring)
  own <- own_drop(b, j) / JnP
  # edge: the panel's three nodes' weights differ by more than 2x after width scaling
  dens <- b$w / pmax((c(wid[1], wid[-length(wid)]) + wid) / 2, 1e-12)
  edge <- sapply(j, function(i) { v <- dens[(i - 1):(i + 1)]; v <- v[is.finite(v)]; min(v) < 0.5 * max(v) })
  cat(sprintf("%s: %d panels, %d edge; own total %+.5f (edge %+.5f, interior %+.5f); |own| edge %.5f interior %.5f\n",
      k, length(j), sum(edge), sum(own), sum(own[edge]), sum(own[!edge]), sum(abs(own[edge])), sum(abs(own[!edge]))))
  bb <- cut(b$birth[j], c(0, 0.5, 1, 2, 4, 8, 16, 40), right = FALSE)
  print(round(tapply(own, bb, sum), 5))
}
