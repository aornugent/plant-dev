# q4_model2.R: the a-priori magnitude model with the proxy normalised by the pilot's J
# (weights (nrr / J_pilot)^0.6), as a sum of independent error powers:
#   rms^2 = aF zF^2 + aS zS^2 + aE zE^2 + aL zL^2 + sigma^2(tol, gate)
# z the normalised band proxies (founders, spells b1-25, late) and the edge-node term.
# Fitted on nine cases, scored on the tenth; against the log-linear form of q4_model.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
d <- readRDS(file.path(OUT, "q4_data.rds"))
Jp <- vapply(ALL, function(cs) pilot_ctx(cs)$J, 0); d$Jp <- Jp[d$case]; n6 <- d$Jp^0.6
d$zF <- d$proxyF / n6; d$zS <- (d$proxyA + d$proxyB) / n6; d$zL <- d$proxyL / n6; d$zE <- (d$edgeC2 + d$edgeO2) / n6
d$t3 <- as.numeric(d$tol == 3e-4); d$t1 <- as.numeric(d$tol == 1e-4); d$t5 <- as.numeric(d$tol < 1e-4); d$ag <- as.numeric(d$build == "AG")
Z <- function(d) cbind(F = d$zF^2, S = d$zS^2, E = d$zE^2, L = d$zL^2, j5 = d$t5, j1 = d$t1, j3 = d$t3, ag = d$ag)
fit <- function(d) { X <- Z(d); y <- d$rms^2; sc <- apply(X, 2, function(x) max(mean(x), 1e-12))
  obj <- function(lb) { b <- exp(lb); mean((log(X %*% (b / sc) + 1e-6) - log(y))^2) }
  o <- optim(rep(log(mean(y) / ncol(X)), ncol(X)), obj, method = "BFGS", control = list(maxit = 2000)); exp(o$par) / sc }
pred <- function(b, d) sqrt(Z(d) %*% b)
r <- rep(NA, nrow(d)); for (cs in unique(d$case)) { tr <- d$case != cs; b <- fit(d[tr, ]); r[!tr] <- log(d$rms[!tr]) - log(pred(b, d[!tr, ])) }
q <- function(r, lab) cat(sprintf("  %-44s LOCO: median factor x%.2f, 90%% x%.2f, within x2 %3.0f%% | R2 of log rms %+.2f\n", lab, exp(median(abs(r))), exp(quantile(abs(r), 0.9)), 100 * mean(abs(r) < log(2)), 1 - sum(r^2) / sum((log(d$rms) - mean(log(d$rms)))^2)))
cat(nrow(d), "runs, 10 cases\n"); q(r, "variance sum, normalised proxies")
b <- fit(d); cat("  in-sample coefficients:", paste(sprintf("%s %.3g", colnames(Z(d)), b), collapse = ", "), "\n")
cat("  implied jitter floor (rms eps): 3e-5", round(sqrt(b["j5"]), 3), " 1e-4", round(sqrt(b["j1"]), 3), " 3e-4", round(sqrt(b["j3"]), 3), " gate adds", round(sqrt(b["ag"]), 3), "\n")
for (cs in unique(d$case)) { j <- d$case == cs; cat(sprintf("     %-13s n %3d median actual/pred x%.2f | within x2 %3.0f%%\n", cs, sum(j), exp(median(r[j])), 100 * mean(abs(r[j]) < log(2)))) }
# log-linear with normalised proxies
d$xF <- log(d$zF); d$xS <- log(d$zS); d$xL <- log(d$zL); d$xE <- log(d$zE + 1e-6)
r2 <- rep(NA, nrow(d)); fm <- log(rms) ~ xF + xS + xL + xE + x_tol + x_AG
for (cs in unique(d$case)) { tr <- d$case != cs; r2[!tr] <- log(d$rms[!tr]) - predict(lm(fm, d[tr, ]), d[!tr, ]) }
q(r2, "log-linear, normalised proxies")
# committed-like runs only (the val pairs' c side at 1e-4)
j <- grepl("^val_.*_c_|^P_insc|^P_mid_|^P_ins3c", d$name)
cat("\n  on committed runs only (n", sum(j), "):\n"); q(r[j], "variance sum, normalised proxies"); q(r2[j], "log-linear, normalised proxies")
# a flag: predicted worst > eps? worst ~ ratio * rms, ratio fitted LOCO
wr <- rep(NA, nrow(d)); for (cs in unique(d$case)) { tr <- d$case != cs; wr[!tr] <- exp(median(log(d$worst[tr] / d$rms[tr]))) }
pw <- exp(log(d$rms) - r) * wr
for (th in c(0.5, 1)) { a <- d$worst > th; p <- pw > th
  cat(sprintf("  flag 'worst > %.1f eps' from the a-priori model: sensitivity %.0f%%, specificity %.0f%% (n %d, %d positive)\n", th, 100 * mean(p[a]), 100 * mean(!p[!a]), length(a), sum(a))) }
saveRDS(list(d = d, r = r), file.path(OUT, "q4_model2.rds"))
