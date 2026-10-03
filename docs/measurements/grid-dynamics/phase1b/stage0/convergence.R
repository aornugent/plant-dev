# Stage 0, numerically: Dormand-Prince 5(4) and its contd5 dense output, and the
# Cash-Karp C1 quartic from tableau_algebra.py, by convergence on y' = -y, on
# the Riccati y' = y^2 (y = 1/(1 - t)) and on Lotka-Volterra against a classical
# RK4 reference. Slopes of log(error) against log(h): the propagated solution's
# global error 5 and local error 6; the embedded estimate's local error 5; each
# dense output's local error at theta = 1/2 5 (the cubic Hermite 4). Then each
# pair's real stability boundary.
#   Rscript convergence.R > convergence.txt
dp <- local({
  A <- matrix(0, 7, 7)
  A[2, 1] <- 1/5
  A[3, 1:2] <- c(3/40, 9/40)
  A[4, 1:3] <- c(44/45, -56/15, 32/9)
  A[5, 1:4] <- c(19372/6561, -25360/2187, 64448/6561, -212/729)
  A[6, 1:5] <- c(9017/3168, -355/33, 46732/5247, 49/176, -5103/18656)
  b <- c(35/384, 0, 500/1113, 125/192, -2187/6784, 11/84, 0)
  A[7, ] <- b
  bh <- c(5179/57600, 0, 7571/16695, 393/640, -92097/339200, 187/2100, 1/40)
  cc <- c(0, 1/5, 3/10, 4/5, 8/9, 1, 1)
  d <- c(-12715105075/11282082432, 0, 87487479700/32700410799, -10690763975/1880347072,
         701980252875/199316789632, -1453857185/822651844, 69997945/29380423)
  list(A = A, b = b, bh = bh, c = cc, d = d)
})
ck <- local({
  A <- matrix(0, 7, 7)
  A[2, 1] <- 1/5
  A[3, 1:2] <- c(3/40, 9/40)
  A[4, 1:3] <- c(3/10, -9/10, 6/5)
  A[5, 1:4] <- c(-11/54, 5/2, -70/27, 35/27)
  A[6, 1:5] <- c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096)
  b <- c(37/378, 0, 250/621, 125/594, 0, 512/1771, 0)
  A[7, ] <- b
  bh <- c(2825/27648, 0, 18575/48384, 13525/55296, 277/14336, 1/4, 0)
  cc <- c(0, 1/5, 3/10, 3/5, 1, 7/8, 1)
  # the C1 quartic's theta^1..theta^4 weights (tableau_algebra.py, mu = -3492/989)
  B <- rbind(c(1, 0, 0, 0, 0, 0, 0),
             c(-156473/57792, 0, 1159825/332304, 14725/60544, 5301/38528, -202836/76153, 3/2),
             c(729889/260064, 0, -8030425/1495368, 290425/817344, -5301/19264, 493736/76153, -4),
             c(-24797/24768, 0, 2275475/996912, -19225/49536, 5301/38528, -3492/989, 5/2))
  list(A = A, b = b, bh = bh, c = cc, B = B)
})

# One step of tableau tb from (t, y) of size h: the stages (seven, the last at
# y1), y1, the embedded solution, and the dense outputs at theta.
one_step <- function(tb, f, t, y, h) {
  k <- matrix(0, length(y), 7)
  k[, 1] <- f(t, y)
  for (i in 2:7) k[, i] <- f(t + tb$c[i] * h, y + h * k[, 1:(i - 1), drop = FALSE] %*% tb$A[i, 1:(i - 1)])
  y1 <- y + h * k %*% tb$b
  yh <- y + h * k %*% tb$bh
  list(k = k, y1 = as.vector(y1), yh = as.vector(yh))
}
dense_dp <- function(s, y0, h, th) {
  r2 <- s$y1 - y0; r3 <- h * s$k[, 1] - r2; r4 <- r2 - h * s$k[, 7] - r3
  r5 <- h * as.vector(s$k %*% dp$d)
  y0 + th * (r2 + (1 - th) * (r3 + th * (r4 + (1 - th) * r5)))
}
dense_ck <- function(s, y0, h, th) y0 + h * as.vector(s$k %*% as.vector(th^(1:4) %*% ck$B))
hermite <- function(s, y0, h, th) {
  (1 + 2 * th) * (1 - th)^2 * y0 + th * (1 - th)^2 * h * s$k[, 1] + th^2 * (3 - 2 * th) * s$y1 +
    th^2 * (th - 1) * h * s$k[, 7]
}

rk4_ref <- function(f, t0, y0, t1, n) {
  h <- (t1 - t0) / n; y <- y0; t <- t0
  for (i in seq_len(n)) {
    k1 <- f(t, y); k2 <- f(t + h / 2, y + h / 2 * k1); k3 <- f(t + h / 2, y + h / 2 * k2)
    k4 <- f(t + h, y + h * k3); y <- y + h / 6 * (k1 + 2 * k2 + 2 * k3 + k4); t <- t + h
  }
  y
}

problems <- list(
  decay = list(f = function(t, y) -y, y0 = 1, t0 = 0, T = 1, exact = function(t) exp(-t)),
  riccati = list(f = function(t, y) y^2, y0 = 1, t0 = 0, T = 0.5, exact = function(t) 1 / (1 - t)),
  lotka = list(f = function(t, y) c(y[1] * (1.5 - y[2]), y[2] * (y[1] - 1)), y0 = c(2, 0.5), t0 = 0, T = 1,
               exact = NULL))
slope <- function(h, e) unname(coef(lm(log(e) ~ log(h)))[2])

for (nm in names(problems)) {
  P <- problems[[nm]]
  exact <- if (!is.null(P$exact)) P$exact else {
    # an RK4 reference at the grid points needed
    function(t) rk4_ref(P$f, P$t0, P$y0, t, max(1, round((t - P$t0) / 2e-5)))
  }
  cat(sprintf("\n== %s\n", nm))
  for (tbn in c("dp", "ck")) {
    tb <- get(tbn)
    # global error of the propagated solution over [t0, T] with N fixed steps
    Ns <- c(8, 16, 32, 64)
    ge <- sapply(Ns, function(N) {
      h <- (P$T - P$t0) / N; y <- P$y0; t <- P$t0
      for (i in seq_len(N)) { y <- one_step(tb, P$f, t, y, h)$y1; t <- t + h }
      max(abs(y - exact(P$T)))
    })
    # local errors from the exact state at t0, one step of h
    hs <- (P$T - P$t0) * 2^-(2:6)
    loc <- t(sapply(hs, function(h) {
      s <- one_step(tb, P$f, P$t0, P$y0, h)
      ye <- exact(P$t0 + h); ym <- exact(P$t0 + h / 2)
      c(prop = max(abs(s$y1 - ye)), emb = max(abs(s$yh - ye)),
        dense = max(abs((if (tbn == "dp") dense_dp else dense_ck)(s, P$y0, h, 0.5) - ym)),
        cubic = max(abs(hermite(s, P$y0, h, 0.5) - ym)),
        est = max(abs(s$y1 - s$yh)))
    }))
    cat(sprintf("  %s: global error slope %.2f (errors %s)\n", tbn, slope(1 / Ns, ge),
                paste(sprintf("%.2e", ge), collapse = " ")))
    cat(sprintf("      local slopes: propagated %.2f, embedded %.2f, estimate %.2f, dense(1/2) %.2f, cubic Hermite(1/2) %.2f\n",
                slope(hs, loc[, "prop"]), slope(hs, loc[, "emb"]), slope(hs, loc[, "est"]),
                slope(hs, loc[, "dense"]), slope(hs, loc[, "cubic"])))
    cat(sprintf("      at the smallest h: dense(1/2) / estimate %.3f, cubic(1/2) / estimate %.3f\n",
                loc[nrow(loc), "dense"] / loc[nrow(loc), "est"], loc[nrow(loc), "cubic"] / loc[nrow(loc), "est"]))
  }
}

# Real stability boundaries: |R(-x)| <= 1 with R(z) = 1 + z b'(I - zA)^-1 1 on
# the first six stages (b7 = 0).
stab <- function(tb) {
  A6 <- tb$A[1:6, 1:6]; b6 <- tb$b[1:6]
  R <- function(z) 1 + z * sum(b6 * solve(diag(6) - z * A6, rep(1, 6)))
  x <- seq(0.01, 6, by = 1e-4)
  first_bad <- which(sapply(-x, function(z) abs(R(z)) > 1 + 1e-12))[1]
  uniroot(function(x) abs(R(-x)) - 1, c(x[first_bad - 1], x[first_bad]), tol = 1e-12)$root
}
cat(sprintf("\nreal stability boundary: DP %.7f, CK %.7f\n", stab(dp), stab(ck)))
