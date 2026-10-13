# The trend of log|d| in birth date per case, against the pilot's offspring integrand f(b).
source("/home/user/plant-dev/harness/schedule/anyscore.R")
for (case in commandArgs(TRUE)) { cd <- prepare(case); x <- run(sprintf("loc_G0_%s", case)); S <- x$node_times; j <- x$dropped; b <- nd(x)
  m <- own_drop(b, j) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J
  h <- (S[j + 1] - S[j - 1]) / 2; d <- abs(m) / (6 * h^3); bm <- S[j]; ok <- d > 0
  pn <- cd$pilot$nodes; pat <- plant::Weibull_Disturbance_Regime(40); f <- pn$nrr * vapply(pn$birth, pat$density, 0)
  lf <- approx(pn$birth, log(pmax(f, 1e-12)), bm, rule = 2)$y
  fF <- lm(log(d[ok]) ~ lf[ok]); r <- residuals(fF)
  cuts <- c(0, cd$b1, 10, 20, 40); g <- cut(bm[ok], cuts)
  cat(sprintf("%-13s log|d| = %.2f + %.2f log f: R2 %.2f, resid sd %.2f | mean resid by band %s | slope in b over [0,20]: d %.2f, f %.2f\n",
    case, coef(fF)[1], coef(fF)[2], summary(fF)$r.squared, sd(r), paste(sprintf("%+.2f", tapply(r, g, mean)), collapse = " "),
    coef(lm(log(d[ok & bm < 20]) ~ bm[ok & bm < 20]))[2], coef(lm(lf[ok & bm < 20] ~ bm[ok & bm < 20]))[2])) }
