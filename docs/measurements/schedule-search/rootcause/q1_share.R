# q1_share.R: the variance-sum model (q4_model2, fitted on all ten cases) read as a split of
# each a09 committed run's squared error into founders, spells to 25, late and jitter. Inferred.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
d <- readRDS(file.path(OUT, "q4_model2.rds"))$d
Z <- function(d) cbind(F = d$zF^2, S = d$zS^2, E = d$zE^2, L = d$zL^2, j5 = d$t5, j1 = d$t1, j3 = d$t3, ag = d$ag)
X <- Z(d); y <- d$rms^2; sc <- apply(X, 2, function(x) max(mean(x), 1e-12))
b <- exp(optim(rep(log(mean(y) / ncol(X)), ncol(X)), function(lb) mean((log(X %*% (exp(lb) / sc) + 1e-6) - log(y))^2), method = "BFGS", control = list(maxit = 2000))$par) / sc
for (cs in ALL) { j <- which(d$name == sprintf("val_%s_c_%s", if (cs %in% c("long-drought")) "a09p" else "a09", cs))[1]; if (is.na(j)) next
  p <- X[j, ] * b; tot <- sum(p); cat(sprintf("  %-13s actual rms %.2f model %.2f | founders %3.0f%% spells<25 %3.0f%% late %3.0f%% jitter %3.0f%%\n", cs, d$rms[j], sqrt(tot),
    100 * p["F"] / tot, 100 * (p["S"] + p["E"]) / tot, 100 * p["L"] / tot, 100 * sum(p[c("j5", "j1", "j3", "ag")]) / tot)) }
