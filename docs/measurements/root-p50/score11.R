# Round 11: late-uniform ladders on dry and dry-flat; root_P50 elasticity and ln J.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); u <- 0.02; eps <- 0.01075; epsJ <- 0.025
for (rec in c("dry", "dry-flat")) {
  J <- function(k, s) { f <- file.path(Q, sprintf("rp_UL%d_%s_%s.rds", k, s, rec)); if (file.exists(f)) readRDS(f)$stand$J else NA }
  e <- sapply(0:3, function(k) (log(J(k, "0.02")) - log(J(k, "-0.02"))) / (2 * u)); l <- sapply(0:3, function(k) (log(J(k, "0.02")) + log(J(k, "-0.02"))) / 2)
  m <- diff(e) / eps; mj <- diff(l) / epsJ
  cat(sprintf("%-8s root_P50 %s | moves %s eps | ratios %s\n", rec, paste(sprintf("%.5f", e), collapse = " "), paste(sprintf("%+.3f", m), collapse = " "), paste(sprintf("%.2f", head(m, -1) / m[-1]), collapse = " ")))
  cat(sprintf("%-8s ln J moves %s eps | ratios %s\n", "", paste(sprintf("%+.3f", mj), collapse = " "), paste(sprintf("%.2f", head(mj, -1) / mj[-1]), collapse = " "))) }
