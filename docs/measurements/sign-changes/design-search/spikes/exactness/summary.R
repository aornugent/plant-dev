# Nudge spread and bias of the elasticities at tol 1e-4 over seven tolerances,
# every arm on its own adaptive mesh, against the reference (split at 1e-8).
ref <- readRDS("ref_split_1e-08.rds")$r
files <- c(plain = "exp1_1e-04.rds", endpoint = "exp1_1e-04_endpoint.rds", dense2 = "exp1_1e-04_dense2.rds", slope = "exp1_1e-04_slope.rds")
base <- readRDS("exp1_1e-04.rds")
arms <- list(plain = base$plain$E, smooth = base$smooth$E, bracket = base$bracket$E, split = base$split$E,
             endpoint = readRDS(files["endpoint"])$endpoint$E, dense2 = readRDS(files["dense2"])$dense2$E, slope = readRDS(files["slope"])$slope$E)
cat(sprintf("%-9s %-24s %-24s %-24s %-22s\n", "arm", "e1 range / mean-ref", "e2 range / mean-ref", "e3 range / mean-ref", "lnJ range / mean-ref"))
for (a in names(arms)) {
  E <- arms[[a]]
  f <- function(k) sprintf("%.2e / %+.2e", diff(range(E[, k])), mean(E[, k]) - ref[k])
  cat(sprintf("%-9s %-24s %-24s %-24s %-22s\n", a, f(2), f(3), f(4), f(1)))
}
