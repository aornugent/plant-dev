# Is the panel's height structure just one growth curve in age? Build h(b, t) from the
# middle cohort's trajectory shifted by birth date, h_mid(t - (b - b_mid)), and compare
# its coarsening/bisection defects with the measured ones.
x <- readRDS("traj.rds"); b <- x$times; g <- x$grid; H <- x$all$height
bm <- b[50]; hm <- approxfun(g, H[, 50], rule = 2)
defect <- function(f, m, a, c) { fa <- approx(b, f, a, rule = 2)$y; fc <- approx(b, f, c, rule = 2)$y; fm <- approx(b, f, m, rule = 2)$y; l <- (m - a) / (c - a); fm - ((1 - l) * fa + l * fc) }
A <- 7.985226; M <- 8.148148; Z <- 8.518519
for (t in c(9, 9.5, 10, 10.5, 11, 12, 14, 17, 20)) { k <- which.min(abs(g - t))
  f <- H[k, ]; s <- hm(g[k] - (b - bm)); ok <- g[k] - (b - bm) >= min(g)
  cat(sprintf("t %5.1f | measured dC %+.4f dB %+.4f (ratio %6.2f) | age-shifted curve dC %+.4f dB %+.4f (ratio %6.2f) | max |h - shifted| %.3f\n", t,
    defect(f, M, A, Z), defect(f, 8.066687, A, M) + defect(f, 8.333333, M, Z), defect(f, M, A, Z) / (defect(f, 8.066687, A, M) + defect(f, 8.333333, M, Z)),
    defect(s, M, A, Z), defect(s, 8.066687, A, M) + defect(s, 8.333333, M, Z), defect(s, M, A, Z) / (defect(s, 8.066687, A, M) + defect(s, 8.333333, M, Z)), max(abs(f - s)[ok]))) }
