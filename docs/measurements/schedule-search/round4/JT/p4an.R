# p4an.R: Part 4's prediction from P4_F_{A,B}: each step's c_k (adjoint-weighted quadrature
# error of F) in eps of the elasticities, against the measured A - B, by window.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R"))
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
ld <- function(n) { F <- readRDS(file.path(O, paste0("P4_F_", n, ".rds"))); x <- readRDS(file.path(O, paste0("P4_lam_", n, ".rds")))
  nm <- names(x$gradient); e <- eps_vec(sub("^1\\.", "", nm)); s <- ifelse(x$theta == 0, 1, x$theta) / x$J / e
  F <- Filter(function(f) !is.null(f$c_all), F)
  d <- do.call(rbind, lapply(F, function(f) data.frame(t0 = f$t0, h_d = f$h * 365, n = f$n, up = f$up, umin = min(f$u), umax = max(f$u),
    c = f$c_all[nm == "1.TF24_cost_scale"] * s[nm == "1.TF24_cost_scale"], c_soil = f$c_soil[nm == "1.TF24_cost_scale"] * s[nm == "1.TF24_cost_scale"],
    lam1 = f$lam_soil[1], dF1 = f$dF_soil[1, nm == "1.TF24_cost_scale"], wgt = sum(f$lam_soil * f$dF_soil[, nm == "1.TF24_cost_scale"]) * s[nm == "1.TF24_cost_scale"])))
  list(d = d, C = do.call(rbind, lapply(F, function(f) f$c_soil * s)), x = x, nm = nm, e = e) }
A <- ld("A"); B <- ld("B"); nm <- A$nm
meas <- (A$x$elasticity - B$x$elasticity) / A$e
pred <- colSums(A$C) - colSums(B$C)
k <- which(nm == "1.TF24_cost_scale")
cat(sprintf("TF24_cost_scale: measured A-B %+.4f eps, predicted %+.4f (A alone %+.4f, B %+.4f); cos over traits %.2f; rms measured %.4f predicted %.4f\n",
  meas[k], pred[k], sum(A$C[, k]), sum(B$C[, k]), sum(meas * pred) / sqrt(sum(meas^2) * sum(pred^2)), sqrt(mean(meas^2)), sqrt(mean(pred^2))))
brk <- c(0, 3.5, 5, 6.7, 8.25, 9.15, 9.678, 9.753, 10.04, 17, 25, 40)
wa <- tapply(A$d$c_soil, cut(A$d$t0, brk), sum); wb <- tapply(B$d$c_soil, cut(B$d$t0, brk), sum)
ga <- tapply(abs(A$d$wgt), cut(A$d$t0, brk), max); la <- tapply(abs(A$d$lam1), cut(A$d$t0, brk), median); fa <- tapply(abs(A$d$dF1), cut(A$d$t0, brk), median); ha <- tapply(A$d$h_d, cut(A$d$t0, brk), median); na <- tapply(A$d$n, cut(A$d$t0, brk), sum)
print(data.frame(window = names(wa), pred_AminusB = round(wa - wb, 4), share = round((wa - wb) / pred[k], 2), A = round(wa, 4), B = round(wb, 4),
  max_abs_weight = signif(ga, 2), med_lam1 = signif(la, 2), med_dF1 = signif(fa, 2), median_h_d = round(ha, 2), switches = na), row.names = FALSE)
saveRDS(list(A = A$d, B = B$d, pred = pred, meas = meas), file.path(O, "P4_an.rds"))
cat("\nA's largest |c| steps (TF24_cost_scale, eps):\n"); print(head(A$d[order(-abs(A$d$c_soil)), ], 15), digits = 3)
