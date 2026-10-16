# q4_bound.R: as a stopping rule, how well does each predictor bound a committed run's
# worst error (eps units), leave-one-case-out, on the stored committed/check pairs?
#  check:    max |(c - f)/(1 - s)| (the gradient check; per quantity, signed)
#  prior:    a-priori rms (q4_model2's variance sum, normalised proxies) x kappa
#  prior+J:  the prior rescaled by ln J's estimated error from a forward-only check over
#            the prior's own ln J prediction (one scalar per run), x kappa
# kappa is the 90th percentile of worst / predicted rms on the other nine cases' runs.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
M2 <- readRDS(file.path(OUT, "q4_model2.rds")); d <- M2$d
CK <- readRDS(file.path(OUT, "q4_check.rds")); R <- CK$R; EST <- CK$EST
FT <- readRDS(file.path(OUT, "feat.rds")); meta <- FT$meta
Z <- function(d) cbind(F = d$zF^2, S = d$zS^2, E = d$zE^2, L = d$zL^2, j5 = d$t5, j1 = d$t1, j3 = d$t3, ag = d$ag)
fit <- function(d, y) { X <- Z(d); sc <- apply(X, 2, function(x) max(mean(x), 1e-12))
  obj <- function(lb) { b <- exp(lb); mean((log(X %*% (b / sc) + 1e-8) - log(y))^2) }
  exp(optim(rep(log(mean(y) / ncol(X)), ncol(X)), obj, method = "BFGS", control = list(maxit = 2000))$par) / sc }
d$lj2 <- pmax(d$lnJ^2, 1e-4)
# map each pair's committed run to its row in d (same schedule, case, build, tolerance)
dig <- function(id) { S <- RR[[id]]$S; sprintf("%d:%.8f", length(S), sum(S^2)) }
d$key <- paste(d$case, d$build, d$tol, vapply(meta$id[match(d$name, meta$name)], dig, ""))
out <- list()
for (cs in ALL) { tr <- d$case != cs; b <- fit(d[tr, ], d$rms[tr]^2); bj <- fit(d[tr, ], d$lj2[tr])
  prr <- sqrt(Z(d[tr, ]) %*% b); kap <- quantile(d$worst[tr] / prr, 0.9)
  prj <- sqrt(Z(d[tr, ]) %*% bj); calib <- abs(d$lnJ[tr]) / prj   # on training runs, true ln J error over predicted
  kapJ <- quantile(d$worst[tr] / (prr * pmax(calib, 0.1)), 0.9)
  for (i in which(R$case == cs)) { p <- R[i, ]; z <- EST[[i]]; key <- paste(p$case, p$build, p$tol, dig(p$c)); j <- match(key, d$key); if (is.na(j)) next
    pr <- sqrt(Z(d[j, ]) %*% b); pj <- sqrt(Z(d[j, ]) %*% bj); lj <- abs(z$est["lnJ"])
    out[[length(out) + 1]] <- data.frame(case = cs, fam = p$fam, worst = max(abs(z$ec)), chk = max(abs(z$est)), prior = pr * kap, priorJ = pr * max(lj / pj, 0.1) * kapJ) } }
O <- do.call(rbind, out); cat(nrow(O), "committed runs with a stored check\n")
ev <- function(B, lab) { cov <- mean(O$worst <= B); acc <- B <= 1; fa <- mean(O$worst[acc] > 1); fr <- mean(acc[O$worst <= 1])
  cat(sprintf("  %-9s bound covers worst %3.0f%% | bound/worst median %.2f [10-90%%: %.2f, %.2f] | accepts %3.0f%% of runs; of accepted, worst > eps %3.0f%%; of runs truly within eps, accepted %3.0f%%\n",
    lab, 100 * cov, median(B / O$worst), quantile(B / O$worst, 0.1), quantile(B / O$worst, 0.9), 100 * mean(acc), 100 * fa, 100 * fr)) }
ev(O$chk, "check"); ev(O$prior, "prior"); ev(O$priorJ, "prior+J")
cat("\n  per case: median bound/worst (check | prior | prior+J)\n")
for (cs in ALL) { j <- O$case == cs; cat(sprintf("   %-13s n %2d  %.2f | %.2f | %.2f\n", cs, sum(j), median(O$chk[j] / O$worst[j]), median(O$prior[j] / O$worst[j]), median(O$priorJ[j] / O$worst[j]))) }
saveRDS(O, file.path(OUT, "q4_bound.rds"))
