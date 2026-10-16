# q4_model.R: predict a run's error size from what is known before it (schedule geometry
# against the pilot, tolerance, build) or within it (its own nodes' outputs), tested
# leave-one-case-out. Targets: log rms error over the quantities, log worst, log |ln J|.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
FT <- readRDS(file.path(OUT, "feat.rds")); meta <- FT$meta; E <- FT$E; F <- as.data.frame(FT$F)
ok <- meta$build %in% c("L19", "AG") & complete.cases(E) & meta$rms <= 1.5 & (is.na(meta$atol) | meta$atol == 1e-4) &
  meta$hmax %in% c("15", "") & !grepl("^JT|^E_|^G_|^R_|^S_", meta$name)
d <- cbind(meta[ok, c("name", "case", "build", "tol", "rms", "worst", "lnJ", "alongM")], F[ok, ])
d$lrms <- log(d$rms); d$lworst <- log(d$worst); d$llnJ <- log(pmax(abs(d$lnJ), 0.01))
lg <- function(x) log(pmax(x, 1e-12))
d$x_proxy <- lg(d$proxy); d$x_F <- lg(d$proxyF); d$x_AB <- lg(d$proxyA + d$proxyB); d$x_L <- lg(d$proxyL)
d$x_edge <- lg(d$edgeC2 + d$edgeO2 + 1e-3); d$x_tol <- log10(d$tol); d$x_AG <- as.numeric(d$build == "AG"); d$x_n <- log(d$n)
d$x_hF <- log(d$hF_max); d$x_cur <- lg(d$cur); d$x_curE <- lg(d$curE + 1e-9)
cat(nrow(d), "runs,", length(unique(d$case)), "cases\n")
models <- list(
  `proxy only (a09's)` = lrms ~ x_proxy,
  `proxy + tol` = lrms ~ x_proxy + x_tol,
  `bands: founders, spells, late + tol` = lrms ~ x_F + x_AB + x_L + x_tol,
  `bands + edge-node term + tol + gate` = lrms ~ x_F + x_AB + x_L + x_edge + x_tol + x_AG,
  `node count + tol` = lrms ~ x_n + x_tol,
  `in-run node curvature + tol` = lrms ~ x_cur + x_curE + x_tol,
  `bands + edge + in-run curvature` = lrms ~ x_F + x_AB + x_L + x_edge + x_tol + x_AG + x_cur + x_curE)
# Variance-sum model: rms^2 = sum_k b_k z_k + b0(tol), b >= 0 (nnls), z the band proxies
# scaled per case-free units; error powers add if bands are uncorrelated.
loco <- function(fm, y = all.vars(fm)[1]) { pr <- rep(NA, nrow(d))
  for (cs in unique(d$case)) { tr <- d$case != cs; m <- lm(fm, d[tr, ]); pr[!tr] <- predict(m, d[!tr, ]) }
  r <- d[[y]] - pr; c(R2 = 1 - sum(r^2) / sum((d[[y]] - mean(d[[y]]))^2), med_x = exp(median(abs(r))), p90_x = exp(quantile(abs(r), 0.9)), within2 = mean(abs(r) < log(2)), insample_R2 = summary(lm(fm, d))$r.squared) }
cat("\n== log rms error, leave-one-case-out (factor errors: exp|residual|)\n")
for (nm in names(models)) { z <- loco(models[[nm]]); cat(sprintf("  %-40s LOCO R2 %+.2f | median x%.2f, 90%% x%.2f | within x2 %.0f%% | in-sample R2 %.2f\n", nm, z["R2"], z["med_x"], z["p90_x"], 100 * z["within2"], z["insample_R2"])) }
cat("\n  case effect alone (in-sample R2 of lrms ~ case):", round(summary(lm(lrms ~ case, d))$r.squared, 2),
  "; bands + edge + tol within case (case fixed effects, in-sample):", round(summary(lm(lrms ~ case + x_F + x_AB + x_L + x_edge + x_tol + x_AG, d))$r.squared, 2), "\n")
m <- lm(models[[4]], d); print(round(coef(summary(m)), 3))
cat("\n== same predictors for log worst and log |ln J|\n")
for (y in c("lworst", "llnJ")) for (nm in names(models)[c(1, 4, 7)]) { fm <- update(models[[nm]], as.formula(paste(y, "~ ."))); z <- loco(fm, y)
  cat(sprintf("  %-7s %-40s LOCO R2 %+.2f | median x%.2f, 90%% x%.2f | within x2 %.0f%%\n", y, nm, z["R2"], z["med_x"], z["p90_x"], 100 * z["within2"])) }
# Per-case residual bias of the best a-priori model: is the miss a case constant?
pr <- rep(NA, nrow(d)); fm <- models[[4]]
for (cs in unique(d$case)) { tr <- d$case != cs; pr[!tr] <- predict(lm(fm, d[tr, ]), d[!tr, ]) }
r <- d$lrms - pr
cat("\n== per held-out case: median factor (actual/predicted) and spread of the bands+edge model\n")
for (cs in unique(d$case)) { j <- d$case == cs; cat(sprintf("  %-13s n %3d median x%.2f | sd of log residual %.2f | spread after removing the case's median: within x2 %.0f%%\n", cs, sum(j), exp(median(r[j])), sd(r[j]), 100 * mean(abs(r[j] - median(r[j])) < log(2)))) }
cat(sprintf("\n  with each case's own median removed (one calibration run per case would supply it): within x2 %.0f%%, median x%.2f\n",
  100 * mean(abs(r - ave(r, d$case, FUN = median)) < log(2)), exp(median(abs(r - ave(r, d$case, FUN = median))))))
saveRDS(d, file.path(OUT, "q4_data.rds"))
