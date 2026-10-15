# bias.R: is the stopped runs' error against the reference one smooth direction? Cosines
# between error vectors (elasticities, eps) and the order in tol it falls at.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R"))
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/lean"
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
f <- c(ref = "L1_ref_3e-5_stop", s1e3 = "L1_1e-3_stop", s9.5e4 = "L1_9.5e-4_stop", s3e4 = "JT8_ins_3e-4_stop", s2.85e4 = "JT8_ins_2.85e-4_stop",
  both3e4 = "L2_both_3e-4", u1e4 = "L1_1e-4_none", A = "P_ins3c_dry", B = "X_ins3c_2.85e-4_dry", b50A = "L3_b50_A", b50B = "L3_b50_B",
  both1.5e4 = "X1_both_1.5e-4", both1e4 = "X1_both_1e-4")
p <- function(n) { for (d in c(O, file.path(S, c("JT_out", "P_out/runs", "X_out/runs")))) { g <- file.path(d, paste0(n, ".rds")); if (file.exists(g)) return(readRDS(g)) }; NULL }
x <- Filter(Negate(is.null), lapply(f, p)); q <- lapply(x, quantities); k <- setdiff(Reduce(intersect, lapply(q, names)), "lnJ")
E <- sapply(q[-1], function(v) (v[k] - q$ref[k]) / eps_vec(k))
cosm <- crossprod(E) / sqrt(outer(colSums(E^2), colSums(E^2)))
print(round(cosm, 2)); cat("\nrms:", round(sqrt(colMeans(E^2)), 4), "\n")
cat("order in tol, stopped 1e-3 vs 3e-4:", log(sqrt(mean(E[, "s1e3"]^2)) / sqrt(mean(E[, "s3e4"]^2))) / log(1e-3 / 3e-4), "\n")
# projection of each error on the stopped 3e-4 error direction, and the residual
u <- E[, "s3e4"] / sqrt(sum(E[, "s3e4"]^2))
cat("along s3e4 direction (rms units):", round(colSums(E * u) / sqrt(length(k)), 4), "\nresidual rms:", round(sqrt(colMeans((E - outer(u, colSums(E * u)))^2)), 4), "\n")
