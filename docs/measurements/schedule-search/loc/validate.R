# Leave one run out: predict every quantity's error of the held-out run from factors fitted
# on the rest; report the miss in eps against predicting zero.
source("/home/user/plant-dev/harness/schedule/anysched.R")
for (case in commandArgs(TRUE)) { cd <- case_data(case); rs <- cd$runs; Qs <- Reduce(intersect, lapply(rs, function(r) names(r$err)))
  cat(sprintf("== %s: %d runs, %d panels\n", case, length(rs), nrow(cd$P)))
  for (i in seq_along(rs)) { tr <- rs[-i]; pr <- sapply(Qs, function(Q) if (Q == "lnJ") rs[[i]]$X[["lnJ_signed"]] else predict_err(rs[[i]], fit_kappa(tr, Q)))
    e <- rs[[i]]$err[Qs]; cat(sprintf("%-26s rms miss %.3f (zero %.3f), max miss %.2f, lnJ err %+.2f pred %+.2f\n", rs[[i]]$name, sqrt(mean((pr - e)^2)), sqrt(mean(e^2)), max(abs(pr - e)), e["lnJ"], pr["lnJ"])) } }
