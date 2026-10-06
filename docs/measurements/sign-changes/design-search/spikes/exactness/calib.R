source("toy.R")
setup(N = 8, T = 3, seed = 1)
th0 <- c(2, 0.2, 0.05)
t0 <- proc.time()[3]
reset_counts()
a <- run_adaptive(th0, 1e-4)
cat("steps", length(a$times) - 1, "evals", CNT$evals, "secs", proc.time()[3] - t0, "\n")
cat("lnJ", lnJ_of(a$y), "\n")
# crossings: replay plain, record P at each step end and stage signs
times <- a$times
y <- TOY$y0; e <- rates(y, 0, th0); Ps <- matrix(0, TOY$N, length(times)); Ps[, 1] <- e$P
ncross_steps <- 0; kap <- c(); hs <- c(); Hs <- matrix(0, TOY$N, length(times)); Hs[,1] <- TOY$y0[seq(1, 5*TOY$N, 5)]
for (i in 2:length(times)) {
  h <- times[i] - times[i - 1]
  s <- ck_step(times[i - 1], y, h, e, th0, "plain")
  P1 <- s$e_end$P
  ch <- sign(P1) != sign(e$P)
  if (any(ch)) { ncross_steps <- ncross_steps + 1; kap <- c(kap, h * abs(P1[ch] - e$P[ch]) / h / eta * h); hs <- c(hs, rep(h, sum(ch))) }
  y <- s$y; e <- s$e_end; Ps[, i] <- e$P; Hs[, i] <- y[seq(1, 5*TOY$N, 5)]
}
cat("steps with an ends' sign change", ncross_steps, " node crossings", length(kap), "\n")
cat("kappa = |dP| / eta quantiles:", format(quantile(kap, c(0, .1, .5, .9, 1)), digits = 3), "\n")
cat("crossing step h (days) quantiles:", format(quantile(hs * 365, c(0, .1, .5, .9, 1)), digits = 3), "\n")
cat("median step (days)", median(diff(times)) * 365, "\n")
cat("fraction of node-time with P<0:", mean(Ps < 0), "\n")
cat("final heights:", format(Hs[, ncol(Hs)], digits = 3), "\n")
cat("P range:", format(range(Ps), digits = 3), "\n")
Y <- matrix(a$y[1:(5*TOY$N)], nrow = 5); cat("final r:", format(Y[2,]/(0.05*Y[1,]), digits=3), "\n M:", format(Y[4,], digits=3), "\n O:", format(Y[5,], digits=3), "\n")
