# m3b_shape.R CASE: shape in birth date of the interior cohorts' leaf-area proxy x = A * S
# (A = h^(1/a_l2), S = exp(-mortality)) at times 8, 15, 22 y: per res interior interval, the
# slope of ln A and ln S across birth (per year), and the hat's relative over-count
# (mean over the interval of (chord - x) / x), median over intervals.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/split.R")
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/mk_reg.R", local = TRUE)
cs <- commandArgs(TRUE)[1]; tr <- rd5(sprintf("traj_I4_%s", cs))$traj; R <- regions(cs); b <- tr$birth; iv <- which(R$lab %in% c("Ia", "Ib", "Ic"))
for (T in c(8, 15, 22)) { i <- which.min(abs(tr$time - T)); lA <- log(tr$height[i, ]) / 0.306; lS <- -tr$mortality[i, ]
  r <- t(sapply(iv, function(j) { k <- which(b >= R$lo[j] - 1e-9 & b <= R$hi[j] + 1e-9); if (length(k) < 4 || any(is.na(lA[k])) || R$hi[j] > T - 0.3) return(rep(NA, 5)); bb <- b[k]
    x <- exp(lA[k] + lS[k]); ch <- x[1] + (x[length(x)] - x[1]) * (bb - bb[1]) / (diff(range(bb)))
    sA <- coef(lm(lA[k] ~ bb))[2]; sS <- coef(lm(lS[k] ~ bb))[2]; cA <- coef(lm(lA[k] ~ poly(bb, 2, raw = TRUE)))[3] * 2; cS <- coef(lm(lS[k] ~ poly(bb, 2, raw = TRUE)))[3] * 2
    c(sA, sS, cA, cS, mean((ch - x) / x)[1]) }))
  colnames(r) <- c("slope lnA", "slope lnS", "curv lnA", "curv lnS", "over"); r <- r[complete.cases(r), , drop = FALSE]
  cat(sprintf("t = %2d y (n %d intervals born before t - 0.3): median slope ln A %+.2f /y, ln S %+.2f /y | curvature ln A %+.1f, ln S %+.1f /y^2 | hat over-count %.2f%% (IQR %.2f-%.2f)\n", T, nrow(r),
    median(r[, 1]), median(r[, 2]), median(r[, 3]), median(r[, 4]), 100 * median(r[, 5]), 100 * quantile(r[, 5], 0.25), 100 * quantile(r[, 5], 0.75))) }
