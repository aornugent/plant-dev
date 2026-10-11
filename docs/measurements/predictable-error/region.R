# Region by region on the nested placed grids: the pA map drops every other pA
# node (region = two pA intervals); the pA2 map drops every pA2 midpoint. Square
# law: a region's pA move is 4x the sum of its pA2 moves.
source("../adjmap/lib.R")
a <- run("map_e_pA"); c2 <- run("map_e_pA2")
fa <- (a$soil + a$light) / a$stand$J; fc <- (c2$soil + c2$light) / c2$stand$J
ba <- nd(a); bc <- nd(c2)
ja <- a$dropped; jc <- c2$dropped
L <- ba$birth[ja - 1]; R <- ba$birth[ja + 1]; bm <- bc$birth[jc]
reg <- sapply(bm, function(t) { k <- which(L <= t & R > t); if (length(k)) k[1] else NA })
own_a <- own_drop(ba, ja) / sum(ba$w * ba$offspring); own_c <- own_drop(bc, jc) / sum(bc$w * bc$offspring)
d <- data.frame(b = ba$birth[ja], h = 365 * (R - L) / 2,
  A = colSums(fa), C = as.vector(tapply(colSums(fc), factor(reg, levels = seq_along(ja)), sum)),
  Aearly = colSums(fa[1:6, , drop = FALSE]), Cearly = as.vector(tapply(colSums(fc[1:6, , drop = FALSE]), factor(reg, levels = seq_along(ja)), sum)),
  oA = own_a, oC = as.vector(tapply(own_c, factor(reg, levels = seq_along(ja)), sum)))
bins <- cut(d$b, c(0, 0.5, 1, 2, 4, 8, 16, 40), right = FALSE)
s <- function(v) tapply(v, bins, sum, na.rm = TRUE)
out <- rbind(field_pA = s(d$A), field_pA2 = s(d$C), ratio = s(d$A) / s(d$C),
             early_ratio = s(d$Aearly) / s(d$Cearly), late_ratio = (s(d$A) - s(d$Aearly)) / (s(d$C) - s(d$Cearly)),
             own_ratio = s(d$oA) / s(d$oC), spacing_days = tapply(d$h, bins, median))
print(signif(out, 3))
cat("\ntotals: field pA", sum(d$A), " pA2", sum(d$C, na.rm = TRUE), " ratio", sum(d$A) / sum(d$C, na.rm = TRUE), "\n")
cat("          own pA", sum(d$oA), " pA2", sum(d$oC, na.rm = TRUE), " ratio", sum(d$oA) / sum(d$oC, na.rm = TRUE), "\n")
r <- d$A / d$C; big <- abs(d$C) > quantile(abs(d$C), 0.8, na.rm = TRUE)
cat("per-region ratio (largest 20% of regions): quantiles", round(quantile(r[big], c(.1, .25, .5, .75, .9), na.rm = TRUE), 2), "\n")
saveRDS(d, "region_pA.rds")
