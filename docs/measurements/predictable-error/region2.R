# Region by region on two nested maps: map A drops every other node of grid X
# (region = two X intervals); map C drops every midpoint of X2 = X bisected.
# Square law: A = 4 x (sum of C over the region). Also split by window edges.
args <- commandArgs(TRUE); mA <- args[1]; mC <- args[2]
source("../adjmap/lib.R")
P2 <- file.path(D, "schedtest/placed2/runs")
cr <- readRDS(file.path(P2, "pA4_episodic.rds"))$stand$creation
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); edges <- cr$end[e][-length(e)]
a <- run(mA); c2 <- run(mC)
fa <- (a$soil + a$light) / a$stand$J; fc <- (c2$soil + c2$light) / c2$stand$J
ba <- nd(a); bc <- nd(c2); ja <- a$dropped; jc <- c2$dropped
L <- ba$birth[ja - 1]; R <- ba$birth[ja + 1]
reg <- factor(sapply(bc$birth[jc], function(t) { k <- which(L <= t & R > t); if (length(k)) k[1] else NA }), levels = seq_along(ja))
own_a <- own_drop(ba, ja) / sum(ba$w * ba$offspring); own_c <- own_drop(bc, jc) / sum(bc$w * bc$offspring)
S <- function(v) as.vector(tapply(v, reg, sum))
edge <- sapply(seq_along(ja), function(i) any(edges > L[i] & edges < R[i]))
d <- data.frame(b = ba$birth[ja], edge = edge,
  A = colSums(fa), C = S(colSums(fc)), Al = colSums(fa[7:8, , drop = FALSE]), Cl = S(colSums(fc[7:8, , drop = FALSE])),
  oA = own_a, oC = S(own_c))
bins <- cut(d$b, c(0, 0.5, 1, 2, 4, 8, 16, 40), right = FALSE)
tb <- function(v, sel = rep(TRUE, length(v))) tapply(ifelse(sel, v, 0), bins, sum, na.rm = TRUE)
options(width = 200)
print(signif(rbind(field_A = tb(d$A), field_C = tb(d$C), ratio = tb(d$A) / tb(d$C),
  edge_A = tb(d$A, d$edge), edge_C = tb(d$C, d$edge), interior_A = tb(d$A, !d$edge), interior_C = tb(d$C, !d$edge),
  late_A = tb(d$Al), late_C = tb(d$Cl), own_A = tb(d$oA), own_C = tb(d$oC)), 3))
cat(sprintf("\ntotal field A %+.5f C %+.5f ratio %.2f | edge A %+.5f C %+.5f | interior A %+.5f C %+.5f ratio %.2f | |edge| A %.5f C %.5f\n",
  sum(d$A), sum(d$C, na.rm = TRUE), sum(d$A) / sum(d$C, na.rm = TRUE), sum(d$A[d$edge]), sum(d$C[d$edge], na.rm = TRUE),
  sum(d$A[!d$edge]), sum(d$C[!d$edge], na.rm = TRUE), sum(d$A[!d$edge]) / sum(d$C[!d$edge], na.rm = TRUE),
  sum(abs(d$A[d$edge])), sum(abs(d$C[d$edge]), na.rm = TRUE)))
cat(sprintf("own A %+.5f C %+.5f ratio %.2f\n", sum(d$oA), sum(d$oC, na.rm = TRUE), sum(d$oA) / sum(d$oC, na.rm = TRUE)))
o <- order(-abs(d$C))[1:10]; cat("largest C regions:\n"); print(signif(d[o, ], 3))
