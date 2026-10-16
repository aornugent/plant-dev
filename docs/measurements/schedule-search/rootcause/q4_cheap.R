# q4_cheap.R: cheaper estimators of a committed run's error than the gradient check,
# leave-one-case-out on the stored pairs (q4_check.R), against the check's own reads.
#  lnJ-fwd: the check run forward-only; ln J's move/(1 - s) times per-quantity slopes
#           beta_q (err_q on err_lnJ) fitted on the other nine cases' runs.
#  lnJ-mag: the same ln J estimate as a magnitude only, rms = alpha |ln J est|.
#  a-priori: rms from the schedule's band proxies, edge-node term and tolerance (q4_model).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
CK <- readRDS(file.path(OUT, "q4_check.rds")); R <- CK$R; EST <- CK$EST
FT <- readRDS(file.path(OUT, "feat.rds")); meta <- FT$meta; E <- FT$E; Fm <- as.data.frame(FT$F)
tr_ok <- meta$build == "L19" & complete.cases(E) & meta$rms <= 0.6 & meta$tol >= 1e-4
d4 <- readRDS(file.path(OUT, "q4_data.rds"))
fm_prior <- lrms ~ x_F + x_AB + x_L + x_edge + x_tol + x_AG
lg <- function(x) log(pmax(x, 1e-12))
xrow <- function(id) { j <- which(meta$id == id); if (!length(j)) return(NULL); f <- Fm[j[1], ]
  data.frame(x_F = lg(f$proxyF), x_AB = lg(f$proxyA + f$proxyB), x_L = lg(f$proxyL), x_edge = lg(f$edgeC2 + f$edgeO2 + 1e-3), x_tol = log10(meta$tol[j[1]]), x_AG = as.numeric(meta$build[j[1]] == "AG")) }
score <- function(ec, est) { big <- pmax(abs(ec), abs(est)) > 1 / 3; ok3 <- abs(est) >= abs(ec) / 2 & abs(est) <= 2 * abs(ec) & sign(est) == sign(ec)
  c(C3 = if (any(big)) sum(!ok3[big]) <= max(1, floor(0.2 * sum(big))) else TRUE, read = if (any(big)) mean(ok3[big]) else NA,
    C2 = all(abs(est)[abs(ec) > 0.5] > 0.25), corr = cor(est, ec), ratio = sqrt(mean(est^2)) / sqrt(mean(ec^2)),
    flag_ok = (max(abs(est)) > 1) == (max(abs(ec)) > 1), flag_half = (max(abs(est)) > 0.5) == (max(abs(ec)) > 0.5)) }
out <- list()
for (i in seq_len(nrow(R))) { p <- R[i, ]; z <- EST[[i]]; k <- z$k; cs <- p$case
  tr <- tr_ok & meta$case != cs; X <- E[tr, k]
  beta <- colSums(X * X[, "lnJ"]) / sum(X[, "lnJ"]^2)                       # err_q on err_lnJ through the origin
  alpha <- exp(median(log(sqrt(rowMeans(X^2)) / pmax(abs(X[, "lnJ"]), 1e-3))))  # rms / |lnJ|
  lj <- z$est["lnJ"]
  m <- lm(fm_prior, d4[d4$case != cs, ]); xr <- xrow(p$c); prior_rms <- if (is.null(xr)) NA else exp(predict(m, xr))
  sc_chk <- score(z$ec, z$est); sc_lj <- score(z$ec, beta * lj)
  out[[i]] <- data.frame(case = cs, fam = p$fam, build = p$build, tol = p$tol, rms_c = p$rms_c, worst_c = p$worst_c,
    chk_C3 = sc_chk["C3"], chk_read = sc_chk["read"], chk_corr = sc_chk["corr"], chk_ratio = sc_chk["ratio"], chk_flag = sc_chk["flag_ok"], chk_flag5 = sc_chk["flag_half"],
    lj_C3 = sc_lj["C3"], lj_read = sc_lj["read"], lj_corr = sc_lj["corr"], lj_ratio = sc_lj["ratio"], lj_flag = sc_lj["flag_ok"], lj_flag5 = sc_lj["flag_half"],
    ljmag_ratio = alpha * abs(lj) / p$rms_c, prior_ratio = prior_rms / p$rms_c, row.names = NULL) }
O <- do.call(rbind, out)
q <- function(x) sprintf("median %.2f [10-90%%: %.2f, %.2f], within x2 %3.0f%%", median(x, na.rm = TRUE), quantile(x, 0.1, na.rm = TRUE), quantile(x, 0.9, na.rm = TRUE), 100 * mean(abs(log(x)) < log(2), na.rm = TRUE))
rep1 <- function(O, lab) { cat(sprintf("\n== %s (%d pairs, %d cases)\n", lab, nrow(O), length(unique(O$case))))
  cat(sprintf("  check (gradient, finer):    C3 pass %3.0f%%, read median %.2f, corr median %.2f | rms est/err %s | 'worst > eps' flag right %3.0f%%, '> eps/2' %3.0f%%\n",
    100 * mean(O$chk_C3), median(O$chk_read, na.rm = TRUE), median(O$chk_corr), q(O$chk_ratio), 100 * mean(O$chk_flag), 100 * mean(O$chk_flag5)))
  cat(sprintf("  ln J from forward check:    C3 pass %3.0f%%, read median %.2f, corr median %.2f | rms est/err %s | 'worst > eps' flag right %3.0f%%, '> eps/2' %3.0f%%\n",
    100 * mean(O$lj_C3), median(O$lj_read, na.rm = TRUE), median(O$lj_corr), q(O$lj_ratio), 100 * mean(O$lj_flag), 100 * mean(O$lj_flag5)))
  cat(sprintf("  ln J magnitude only:        rms est/err %s\n", q(O$ljmag_ratio)))
  cat(sprintf("  a-priori geometry (LOCO):   rms est/err %s\n", q(O$prior_ratio))) }
rep1(O, "all pairs"); rep1(O[O$tol == 1e-4 & O$build == "L19", ], "lib19, 1e-4")
for (cs in ALL) { j <- O$case == cs; cat(sprintf("  %-13s n %2d | check C3 %3.0f%% corr %.2f | lnJ-fwd C3 %3.0f%% corr %.2f ratio %.2f | lnJ-mag ratio %.2f | prior ratio %.2f\n", cs, sum(j),
  100 * mean(O$chk_C3[j]), median(O$chk_corr[j]), 100 * mean(O$lj_C3[j]), median(O$lj_corr[j]), median(O$lj_ratio[j]), median(O$ljmag_ratio[j]), median(O$prior_ratio[j], na.rm = TRUE))) }
saveRDS(O, file.path(OUT, "q4_cheap.rds"))
