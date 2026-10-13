# Does the pilot (54 even nodes, forward only) show where d(b) is large? Measured |d| at
# the start's panels against the pilot's offspring integrand and its curvature.
source("/home/user/plant-dev/harness/schedule/anyscore.R")
for (case in commandArgs(TRUE)) { cd <- prepare(case); x <- run(sprintf("loc_G0_%s", case)); S <- x$node_times; j <- x$dropped; b <- nd(x)
  m <- own_drop(b, j) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J
  own <- own_drop(b, j) / sum(b$w * b$offspring); h <- (S[j + 1] - S[j - 1]) / 2; d <- abs(m) / (6 * h^3); bm <- S[j]
  pn <- cd$pilot$nodes; pat <- plant::Weibull_Disturbance_Regime(40)
  f <- pn$nrr * vapply(pn$birth, pat$density, 0)          # offspring per unit establishment by birth date
  lf <- approx(pn$birth, log(pmax(f, 1e-12)), bm, rule = 2)$y
  d2 <- abs(approx(pn$birth[-c(1, length(f))], diff(f, differences = 2) / diff(pn$birth)[1]^2, bm, rule = 2)$y)
  R <- approx(pn$birth, rev(cumsum(rev(f))) / sum(f), bm, rule = 2)$y   # share of offspring still to be born after b
  ok <- d > 0
  sp <- function(v) cor(log(d[ok]), v[ok], method = "spearman")
  cat(sprintf("%-13s panels %d | own share of sum|m| %.2f | spearman log|d| vs: log f %.2f, |f''| %.2f, R(b) %.2f, birth %.2f\n",
    case, sum(ok), sum(abs(own)) / sum(abs(m)), sp(lf), sp(log(d2 + 1e-12)), sp(R), sp(-bm))) }
cat("-- beyond the trend in birth date: residuals of log|d| after a smooth fit in b\n")
for (case in commandArgs(TRUE)) { cd <- prepare(case); x <- run(sprintf("loc_G0_%s", case)); S <- x$node_times; j <- x$dropped; b <- nd(x)
  m <- own_drop(b, j) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J
  h <- (S[j + 1] - S[j - 1]) / 2; d <- abs(m) / (6 * h^3); bm <- S[j]; ok <- d > 0
  fit <- loess(log(d[ok]) ~ bm[ok], span = 0.5); res <- residuals(fit)
  pn <- cd$pilot$nodes; pat <- plant::Weibull_Disturbance_Regime(40); f <- pn$nrr * vapply(pn$birth, pat$density, 0)
  cr <- cd$pilot$creation; rate <- approx((cr$start + cr$end) / 2, cr$rate, bm[ok], rule = 2)$y
  # establishment open-time inside each panel, from the pilot's creation record
  open_frac <- vapply(which(ok), function(i) { lo <- S[j[i] - 1]; hi <- S[j[i] + 1]; k <- cr$end > lo & cr$start < hi
    sum(pmin(cr$end[k], hi) - pmax(cr$start[k], lo)) / (hi - lo) }, 0)
  edge_near <- vapply(which(ok), function(i) min(abs(cd$pilot$edges - bm[i])), 0)
  trend_r2 <- 1 - var(res) / var(log(d[ok]))
  cat(sprintf("%-13s trend R2 %.2f, residual sd %.2f (x%.1f) | residual vs: creation rate %.2f, edge distance %.2f, |m| sign + share %.2f\n",
    case, trend_r2, sd(res), exp(sd(res)), cor(res, rate, method = "spearman"), cor(res, edge_near, method = "spearman"), mean(m[ok] > 0))) }
