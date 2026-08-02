# Is dg/dh|_S resolved?  Evaluate it at several step sizes on one patch state
# and compare the spread against its distance from the total derivative C.
source("probes/lib.R"); suppressMessages(library(dplyr))
setwd("/home/user/plant-dev")
p  <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
s1 <- p$strategies[[1]]; h0 <- TF24_Individual(s1)$state("height")
scm <- scm_collect(p, "TF24")
times <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
k <- which.min(abs(times - 2))          # the recruitment window
patch <- scm$history[[k]]; env <- patch$environment
nds <- patch$species[[1]]$nodes; n <- length(nds)
cat("patch age", round(patch$time,3), "with", n, "nodes\n")

epss <- c(1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8)
A <- matrix(NA_real_, n, length(epss)); g <- numeric(n); h <- numeric(n)
for (i in seq_len(n)) {
  ind <- nds[[i]]$individual; ind$compute_rates(env)
  h[i] <- ind$state("height"); g[i] <- ind$rate("height")
  for (j in seq_along(epss)) {
    i2 <- nds[[i]]$individual
    i2$set_state("height", h[i] - epss[j]); i2$compute_rates(env)
    A[i, j] <- (g[i] - i2$rate("height")) / epss[j]
  }
}
nb <- patch$species[[1]]$new_node$individual; nb$compute_rates(env)
hb <- c(h[-1], h0); gb <- c(g[-1], nb$rate("height")); dh <- h - hb
C  <- ifelse(dh > 0, (g - gb)/dh, NA_real_)
ok <- is.finite(C) & seq_len(n) < n

cat("\n  eps        median A     max|A(eps)-A(1e-6)|   median|A-C|\n")
a6 <- A[, epss == 1e-6]
for (j in seq_along(epss))
  cat(sprintf("  %-9g %+11.6f   %-19.4g %.4g\n", epss[j], median(A[ok,j]),
              max(abs(A[ok,j] - a6[ok])), median(abs(A[ok,j] - C[ok]))))
cat(sprintf("\n  spread of A across 5 decades of eps: %.4g\n",
            max(apply(A[ok,,drop=FALSE], 1, function(z) diff(range(z))))))
cat(sprintf("  median |A - C|:                      %.4g\n", median(abs(a6[ok]-C[ok]))))
cat(sprintf("  median |C|:                          %.4g\n", median(abs(C[ok]))))
