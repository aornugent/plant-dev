source("toy.R")
for (cfg in list(c(15, 60, 0.35), c(15, 70, 0.3), c(20, 80, 0.25))) {
  setup2 <- function() {
    set.seed(1)
    tp <- cumsum(runif(200, cfg[1], cfg[2]) / 365); tp <- tp[tp < 4.1]
    TOY$tp <- tp; TOY$Ap <- runif(length(tp), 60, 160); TOY$wp <- runif(length(tp), 1, 2.5) / 365
    TOY$N <- 8; TOY$T <- 4
    H0 <- seq(0.6, 4, length.out = 8); TOY$y0 <- c(rbind(H0, 0.5 * 0.05 * H0, 0, 0, 0), 0.3)
  }
  setup2()
  th0 <- c(2, cfg[3], 0.05)
  reset_counts()
  a <- run_adaptive(th0, 1e-4)
  times <- a$times
  y <- TOY$y0; e <- rates(y, 0, th0); rmin <- c(); ncr <- 0; dP <- c()
  rs <- c()
  for (i in 2:length(times)) {
    s <- ck_step(times[i - 1], y, times[i] - times[i - 1], e, th0, "plain")
    ch <- sign(s$e_end$P) != sign(e$P); ncr <- ncr + sum(ch); dP <- c(dP, abs(s$e_end$P - e$P)[ch])
    Y <- matrix(s$y[1:40], nrow = 5); r <- Y[2, ] / (0.05 * Y[1, ])
    if (any(ch & s$e_end$P > 0)) rs <- c(rs, r[ch & s$e_end$P > 0])
    y <- s$y; e <- s$e_end
  }
  Y <- matrix(a$y[1:40], nrow = 5)
  cat(sprintf("gaps %g-%g th2 %g: steps %d crossings %d lnJ %.4f\n", cfg[1], cfg[2], cfg[3], length(times) - 1, ncr, lnJ_of(a$y)))
  cat("  r at upward crossings quantiles:", format(quantile(rs, c(.1, .5, .9)), digits = 3), "\n")
  cat("  final M:", format(Y[4, ], digits = 3), "\n  final H:", format(Y[1, ], digits = 3), "\n")
  cat("  kappa quantiles:", format(quantile(dP / eta, c(.1, .5, .9)), digits = 3), "\n")
}
