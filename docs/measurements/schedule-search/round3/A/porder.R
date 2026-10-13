# Per-quantity order on dry's c5g schedule (3e-5, 1e-4, 3e-4): m1 = Q(1e-4) - Q(3e-5),
# m2 = Q(3e-4) - Q(1e-4). A power law E = c t^p gives m1/m2 = (1 - 0.3^p)/(3^p - 1).
M <- readRDS("/home/user/plant-dev/docs/measurements/schedule-search/round3/A/tolscale.rds")$moves$dry215
M <- M[rownames(M) != "rooting_depth_max", ]; m1 <- M[, 1]; m2 <- M[, 2]
f <- function(p) (1 - 0.3^p) / (3^p - 1)
pof <- function(r) if (r <= 0) NA else if (r >= f(0.05)) 0 else uniroot(function(p) f(p) - r, c(0.05, 20))$root
big <- abs(m2) > 0.05
cat(sprintf("%d of %d quantities move over 0.05 eps from 1e-4 to 3e-4; of them %d move the other way from 3e-5 to 1e-4\n", sum(big), length(m2), sum(big & sign(m1) != sign(m2))))
for (q in names(m2)[big][order(-abs(m2[big]))]) { r <- m1[q] / m2[q]
  cat(sprintf("  %-26s m1 %+.3f m2 %+.3f ratio %+.3f -> p %s\n", q, m1[q], m2[q], r, if (is.na(pof(r))) "none (sign change)" else sprintf("%.1f", pof(r)))) }
cat(sprintf("|m1| under 0.03 (the jitter floor) on %d of these\n", sum(abs(m1[big]) < 0.03)))
