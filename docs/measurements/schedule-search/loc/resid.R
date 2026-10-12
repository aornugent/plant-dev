# Per quantity: leave-one-run-out miss, rms over runs (f = 8 excluded as outside the use range).
source("/home/user/plant-dev/harness/schedule/anysched.R")
for (case in commandArgs(TRUE)) { cd <- case_data(case); rs <- cd$runs; rs <- rs[!grepl("_f8_", sapply(rs, `[[`, "name"))]
  Qs <- Reduce(intersect, lapply(rs, function(r) names(r$err)))
  M <- sapply(seq_along(rs), function(i) sapply(Qs, function(Q) (if (Q == "lnJ") rs[[i]]$X[["lnJ_signed"]] else predict_err(rs[[i]], fit_kappa(rs[-i], Q))) - rs[[i]]$err[Q]))
  r <- sqrt(rowMeans(M^2)); o <- order(-r)
  cat(sprintf("== %s: median rms %.3f; worst: %s\n", case, median(r), paste(sprintf("%s %.2f", Qs[o[1:6]], r[o[1:6]]), collapse = ", "))) }
