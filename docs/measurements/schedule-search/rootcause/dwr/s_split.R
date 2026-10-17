# s_split.R CASE: does ln J's region split predict the elasticities' split? Region errors on res
# from the p50 refinement runs (as r1_score.R), regions F2, I4, Os4, Ofirst4, L4, B. Per
# quantity, the cosine across regions between ln J's region vector and that quantity's; and
# the share each region would get by ln J's split against its measured share.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
DW <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/dwr"
cs <- commandArgs(TRUE)[1]; base <- rd5(sprintf("cl_res_%s", cs)); er <- err_run(base, cs)
fac <- function(t) { k <- suppressWarnings(as.integer(sub("^[A-Za-z_]+", "", t))); if (is.na(k)) 1 else -k^2 / (k^2 - 1) }
tags <- c(F = "F2", I = "I4", Ia = "Ia4", Ib = "Ib4", Ic = "Ic4", Os = "Os4", O1 = "Ofirst4", L = "L4", B = "B")
E <- t(sapply(tags, function(t) { f <- file.path(P5, "runs", sprintf("p5_%s_%s.rds", t, cs)); if (!file.exists(f)) return(rep(NA, length(er)))
  fac(t) * mv_run(readRDS(f), base)[names(er)] })); colnames(E) <- names(er)
saveRDS(list(E = E, e_res = er), file.path(DW, sprintf("regions_measured_%s.rds", cs)))
R6 <- c("F", "I", "Os", "O1", "L", "B"); E6 <- E[R6, , drop = FALSE]
cosv <- function(a, b) sum(a * b) / sqrt(sum(a^2) * sum(b^2))
cs_all <- apply(E6, 2, function(v) cosv(E6[, "lnJ"], v))
cat(sprintf("%s: region errors on res (eps)\n", cs)); print(round(E[, KEY], 2))
cat("\ncos(ln J's region vector, quantity's), key quantities:\n"); print(round(cs_all[KEY[-1]], 2))
cat(sprintf("median |cos| key %.2f; all %d elasticities: median |cos| %.2f, share |cos| >= 0.7 %.2f\n", median(abs(cs_all[KEY[-1]])),
  length(cs_all) - 1, median(abs(cs_all[-1])), mean(abs(cs_all[-1]) >= 0.7)))
rmsp <- sqrt(rowMeans(E6[, -1]^2)); cat(sprintf("rms-over-elasticities profile %s; cos with |ln J| profile %.2f, with ln J %.2f\n",
  paste(sprintf("%s %.3f", R6, rmsp), collapse = " "), cosv(abs(E6[, "lnJ"]), rmsp), cosv(E6[, "lnJ"], rmsp)))
# ln J's split applied to a quantity: each region gets total_k * e_lnJ,g / total_lnJ.
for (k in c("root_P50", "omega", "a_l1", "stem_c")) cat(sprintf("%-9s measured %s | by ln J's split %s\n", k,
  paste(sprintf("%s %+.2f", R6, E6[, k]), collapse = " "), paste(sprintf("%s %+.2f", R6, sum(E6[, k]) * E6[, "lnJ"] / sum(E6[, "lnJ"])), collapse = " ")))
