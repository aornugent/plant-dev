# moves.R CASE BASE19 BASEAG V...: each variant V's move against its base on both gates,
# lib19 (P_V_CASE - BASE19) and libAG (AG_V_CASE - BASEAG), in eps, and how they align.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
a <- commandArgs(TRUE); cs <- a[1]; b19 <- quantities(ag_run(a[2])); bAG <- quantities(ag_run(a[3]))
for (v in a[-(1:3)]) { x19 <- tryCatch(quantities(ag_run(sprintf("P_%s_%s", v, cs))), error = function(e) NULL); xAG <- tryCatch(quantities(ag_run(sprintf("AG_%s_%s", v, cs))), error = function(e) NULL)
  if (is.null(xAG)) next; k <- Reduce(intersect, list(names(b19), names(bAG), names(xAG), if (!is.null(x19)) names(x19) else names(xAG))); e <- eps_vec(k)
  mA <- (xAG[k] - bAG[k]) / e; m1 <- if (!is.null(x19)) (x19[k] - b19[k]) / e else NULL
  cat(sprintf("%-6s libAG move: max %.2f (%s) rms %.3f lnJ %+.3f", v, max(abs(mA)), k[which.max(abs(mA))], sqrt(mean(mA^2)), mA["lnJ"]))
  if (!is.null(m1)) cat(sprintf(" | lib19 move: max %.2f rms %.3f lnJ %+.3f | projection of libAG on lib19 %.2f, corr %.2f", max(abs(m1)), sqrt(mean(m1^2)), m1["lnJ"], sum(mA * m1) / sum(m1^2), cor(mA, m1)))
  cat("\n"); o <- order(-abs(mA))[1:8]; cat("   top libAG:", paste(sprintf("%s %+.2f (lib19 %+.2f)", k[o], mA[o], if (is.null(m1)) NA else m1[o]), collapse = "; "), "\n") }
