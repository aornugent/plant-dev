D <- readRDS("tf24_K_40.rds")
r <- function(a, b) sqrt(mean((a - b)^2)) / sqrt(mean(a^2)); mb <- function(a, b) mean(b - a) / sqrt(mean(a^2))
show <- function(sel, label) {
  cat(sprintf("%-28s n=%5d  rms err / rms K_dense: slope %.3f  stage-quartic+end %.3f  stage-quartic %.3f  line %.3f | bias slope %+.3f  quartic+end %+.3f\n",
    label, sum(sel), r(D$Kd[sel], D$Kslope[sel]), r(D$Kd[sel], D$Ke[sel]), r(D$Kd[sel], D$Ks[sel]), r(D$Kd[sel], D$Kl[sel]),
    mb(D$Kd[sel], D$Kslope[sel]), mb(D$Kd[sel], D$Ke[sel])))
}
show(rep(TRUE, nrow(D)), "all crossing node-steps")
q <- quantile(D$h, c(1/3, 2/3))
show(D$h <= q[1], sprintf("h <= %.2f d", q[1] * 365)); show(D$h > q[1] & D$h <= q[2], "middle third of h"); show(D$h > q[2], sprintf("h > %.2f d", q[2] * 365))
show(D$born < 3.6 & D$t < 25, "born before 3.6, t < 25")
show(D$nroots >= 2, "two or more roots on dense P")
show(abs(D$s) / 1e-4 < 100, "kappa < 100")
cat(sprintf("steps h median %.2f d; |s|/eta median %.3g; roots>=2 share %.3f\n", median(D$h) * 365, median(abs(D$s)) / 1e-4, mean(D$nroots >= 2)))
cat(sprintf("stage point-value error / swing: median %.3f, 90%% %.3f\n", median(D$stage_err / D$range), quantile(D$stage_err / D$range, 0.9)))
