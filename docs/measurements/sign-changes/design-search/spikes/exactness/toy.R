# Toy of TF24's sign changes: a soil state driven by rain pulses and N nodes, each
# with height H, storage S, fecundity F, mortality M and survival-weighted
# offspring O. Net production P reaches growth, fecundity and the storage pool only
# through sigma(P) = (P + sqrt(P^2 + eta^2))/2, as in tf24_strategy.h.
# Methods on one frozen mesh of Cash-Karp steps:
#   plain    the step as plant takes it;
#   smooth   the step plus, per node, h * B * K, where K is the quadrature error of
#            the positive part along the quartic through the stages' net production
#            (weights' stages 1,3,4,6 and stage 5), and B the rates' slope in sigma
#            at P = 0, from the step's start state. Applied before the end rating.
#   bracket  the archive's KINK_FIX: ends' sign change gate, u and Pdot from the
#            bracketing stage pair, sharp kernel, end rated again.
#   split    incumbent-like: each node whose P changes sign on the step's stages or
#            its dense output (32 points) is re-integrated over the step with 32 RK4
#            sub-steps in the field read from Cash-Karp's quartic dense output; end
#            rated again.
eta <- 1e-4
off <- 7 / 365
A <- matrix(0, 6, 6)
A[2, 1] <- 1/5
A[3, 1:2] <- c(3/40, 9/40)
A[4, 1:3] <- c(3/10, -9/10, 6/5)
A[5, 1:4] <- c(-11/54, 5/2, -70/27, 35/27)
A[6, 1:5] <- c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096)
bw <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
d4 <- c(2825/27648, 0, 18575/48384, 13525/55296, 277/14336, 1/4)
cc <- c(0, 1/5, 3/10, 3/5, 1, 7/8)
ec <- bw - d4
BCK4 <- rbind(c(1, 0, 0, 0, 0, 0, 0),
              c(-156473/57792, 0, 1159825/332304, 14725/60544, 5301/38528, -202836/76153, 3/2),
              c(729889/260064, 0, -8030425/1495368, 290425/817344, -5301/19264, 493736/76153, -4),
              c(-24797/24768, 0, 2275475/996912, -19225/49536, 5301/38528, -3492/989, 5/2))
dense_w <- function(u) as.vector(colSums(BCK4 * (u^(1:4))))  # weights on k1..k6, f1, times h

NC <- 5  # components per node: H S F M O
TOY <- new.env()
setup <- function(N = 8, T = 4, seed = 1, rain_scale = 1, gap = c(15, 60)) {
  set.seed(seed)
  tp <- cumsum(runif(200, gap[1], gap[2]) / 365); tp <- tp[tp < T + 0.1]
  TOY$tp <- tp
  TOY$Ap <- runif(length(tp), 60, 160) * rain_scale
  TOY$wp <- runif(length(tp), 1, 2.5) / 365
  TOY$N <- N; TOY$T <- T
  H0 <- seq(0.6, 4, length.out = N)
  S0 <- 0.5 * 0.05 * H0
  TOY$y0 <- c(rbind(H0, S0, 0, 0, 0), 0.3)
}
rain <- function(t) sum(TOY$Ap * exp(-((t - TOY$tp) / TOY$wp)^2))

# Rates at state y, time t, traits th = (th1 assimilation, th2 respiration,
# th3 the pool's mortality scale r0). Returns rates, P, and B (slope of each
# component's rate in sigma at P = 0).
rates <- function(y, t, th) {
  N <- TOY$N
  Y <- matrix(y[1:(NC * N)], nrow = NC)
  H <- Y[1, ]; S <- Y[2, ]; M <- Y[4, ]
  w <- y[NC * N + 1]
  dH <- outer(H, H, function(hi, hj) hj * plogis((hj - hi) / 0.05))  # [i, j]
  shade <- rowSums(dH)
  ell <- 1 / (1 + 0.04 * shade)
  wp <- max(w, 0)
  avail <- wp / (wp + 0.3)
  P <- th[1] * avail * ell * H^0.8 - th[2] * H
  sig <- 0.5 * (P + sqrt(P * P + eta * eta))
  Smax <- 0.05 * H
  r <- S / Smax
  G <- plogis((r - 0.5) / 0.1)
  growth <- sig * G
  rH <- growth * 0.7 / (1 + H)
  rF <- growth * 0.3
  charge <- sig * (1 - G); drain <- sig - P
  relax <- (charge + drain) / Smax
  D <- 1 + relax * off
  rS <- (charge * (1 - r) - drain * r) / D
  rM <- 0.01 + 5.5 * exp(-r / th[3])
  rO <- rF * exp(-M)
  rw <- rain(t) - 50 * w - 0.02 * sum(H * avail * ell)
  list(dydt = c(rbind(rH, rS, rF, rM, rO), rw), P = P,
       state = list(H = H, r = r, G = G, M = M, Smax = Smax))
}
# B at P = 0 from the state parts of an evaluation.
slopes_at_zero <- function(st) {
  s0 <- eta / 2
  a <- (1 - st$G) * (1 - st$r) - st$r
  D0 <- 1 + off * s0 * (2 - st$G) / st$Smax
  N0 <- s0 * a
  bS <- a / D0 - N0 * off * (2 - st$G) / (st$Smax * D0^2)
  bH <- st$G * 0.7 / (1 + st$H)
  bF <- st$G * 0.3
  bO <- bF * exp(-st$M)
  rbind(bH, bS, bF, 0, bO)  # NC x N
}

gfun <- function(P) 0.5 * sqrt(P * P + eta * eta)
GL <- local({  # 12-point Gauss-Legendre on [0, 1]
  x <- c(-0.9815606342467192, -0.9041172563704749, -0.7699026741943047,
         -0.5873179542866175, -0.3678314989981802, -0.1252334085114689)
  w <- c(0.0471753363865118, 0.1069393259953184, 0.1600783285433462,
         0.2031674267230659, 0.2334925365383548, 0.2491470458134028)
  list(x = (c(x, -rev(x)) + 1) / 2, w = c(w, rev(w)) / 2)
})
QN <- c(0, 0.3, 0.6, 0.875, 1)              # stages 1, 3, 4, 6, 5
QV <- solve(outer(QN, 0:4, `^`))            # values -> quartic coefficients
peval <- function(co, u) as.vector(outer(u, 0:4, `^`) %*% co)
# Quadrature error of the positive part along the quartic through the stages,
# one node: K = int_0^1 g(Phat) - sum b_k g(P_k).
kink_K <- function(Pst) {
  vals <- Pst[c(1, 3, 4, 6, 5)]
  co <- QV %*% vals
  ug <- seq(0, 1, length.out = 129)
  pg <- peval(co, ug)
  cuts <- 0
  sc <- which(sign(pg[-1]) != sign(pg[-length(pg)]))
  for (j in sc) {
    f <- function(u) peval(co, u)
    cuts <- c(cuts, uniroot(f, ug[c(j, j + 1)], tol = 1e-15)$root)
  }
  cuts <- c(cuts, 1)
  I <- 0
  for (j in seq_len(length(cuts) - 1)) {
    a <- cuts[j]; b <- cuts[j + 1]
    u <- a + (b - a) * GL$x
    I <- I + (b - a) * sum(GL$w * gfun(peval(co, u)))
  }
  I - sum(bw * gfun(Pst))
}
Ksharp <- function(u) sum(bw * pmax(cc - u, 0)) - (1 - u)^2 / 2
QC <- solve(outer(c(0, 1/3, 2/3, 1), 0:3, `^`))
Gint <- function(P) (P * sqrt(P * P + eta * eta) + eta * eta * asinh(P / eta)) / 4
UF <- seq(0, 1, length.out = 513)
# The integral of g along the cubic through (0, 1/3, 2/3, 1), exact on each of 512
# linear pieces.
int_cubic <- function(vals) {
  P <- as.vector(outer(UF, 0:3, `^`) %*% (QC %*% vals))
  a <- P[-length(P)]; b <- P[-1]; d <- b - a
  small <- abs(d) < 1e-9 * (abs(a) + abs(b) + eta)
  sum(diff(UF) * ifelse(small, gfun((a + b) / 2), (Gint(b) - Gint(a)) / ifelse(small, 1, d)))
}
WSLOPE <- sapply(UF, function(u) as.vector(colSums(BCK4 * ((1:4) * u^(0:3)))))  # 7 x 513
# K along P-hat(u) = sum_i w_i'(u) P_i, the seven values being the six stages'
# and the end's; zero where P-hat keeps one sign on [0, 1].
kink_K_slope <- function(P7, Pst) {
  P <- as.vector(P7 %*% WSLOPE)
  if (all(P > 0) || all(P < 0)) return(0)
  a <- P[-length(P)]; b <- P[-1]; d <- b - a
  small <- abs(d) < 1e-9 * (abs(a) + abs(b) + eta)
  sum(diff(UF) * ifelse(small, gfun((a + b) / 2), (Gint(b) - Gint(a)) / ifelse(small, 1, d))) - sum(bw * gfun(Pst))
}
QE <- c(0, 0.3, 0.6, 0.875, 1)
QVE <- solve(outer(QE, 0:4, `^`))
# As kink_K, along the quartic through the weighted stages and the end's P; zero
# where that quartic keeps one sign on [0, 1], so a step with no crossing is
# untouched.
kink_K_end <- function(vals, Pst) {
  co <- QVE %*% vals
  ug <- seq(0, 1, length.out = 129)
  pg <- peval(co, ug)
  sc <- which(sign(pg[-1]) != sign(pg[-length(pg)]))
  if (!length(sc)) return(0)
  cuts <- 0
  for (j in sc) cuts <- c(cuts, uniroot(function(u) peval(co, u), ug[c(j, j + 1)], tol = 1e-15)$root)
  cuts <- c(cuts, 1)
  I <- 0
  for (j in seq_len(length(cuts) - 1)) {
    a <- cuts[j]; b <- cuts[j + 1]
    I <- I + (b - a) * sum(GL$w * gfun(peval(co, a + (b - a) * GL$x)))
  }
  I - sum(bw * gfun(Pst))
}

CNT <- new.env()
reset_counts <- function() { CNT$evals <- 0; CNT$corr <- 0; CNT$split <- 0; CNT$Kmax_far <- 0 }
reset_counts()
ev <- function(y, t, th) { CNT$evals <- CNT$evals + 1; rates(y, t, th) }

# One Cash-Karp step from (t, y) of size h with first-stage evaluation e1.
# Returns y1, yerr, e_end (evaluation at y1), stages' P.
ck_step <- function(t, y, h, e1, th, method = "plain") {
  N <- TOY$N
  k <- matrix(0, length(y), 6); k[, 1] <- e1$dydt
  Pst <- matrix(0, N, 6); Pst[, 1] <- e1$P
  for (i in 2:6) {
    yi <- y + h * as.vector(k[, 1:(i - 1), drop = FALSE] %*% A[i, 1:(i - 1)])
    e <- ev(yi, t + cc[i] * h, th)
    k[, i] <- e$dydt; Pst[, i] <- e$P
  }
  y1 <- y + h * as.vector(k %*% bw)
  yerr <- h * as.vector(k %*% ec)
  if (method == "smooth") {
    B <- slopes_at_zero(e1$state)
    Kn <- vapply(seq_len(N), function(j) kink_K(Pst[j, ]), 0)
    far <- apply(Pst, 1, function(p) all(abs(p) > 1e-2) && length(unique(sign(p))) == 1)
    if (any(far)) CNT$Kmax_far <- max(CNT$Kmax_far, max(abs(Kn[far])))
    idx <- 1:(NC * N)
    y1[idx] <- y1[idx] + h * as.vector(B %*% diag(Kn, N))
    CNT$corr <- CNT$corr + sum(abs(Kn) > 1e-12)
  }
  e_end <- ev(y1, t + h, th)
  if (method == "endpoint") {
    # The quartic through the weighted stages and the end's own net production
    # (c = 0, .3, .6, .875, 1); the end is rated again where anything was added.
    B <- slopes_at_zero(e1$state)
    Pq <- cbind(Pst[, c(1, 3, 4, 6)], e_end$P)
    Kn <- vapply(seq_len(N), function(j) kink_K_end(Pq[j, ], Pst[j, ]), 0)
    if (any(Kn != 0)) {
      idx <- 1:(NC * N)
      y1[idx] <- y1[idx] + h * as.vector(B %*% diag(Kn, N))
      CNT$corr <- CNT$corr + sum(Kn != 0)
      e_end <- ev(y1, t + h, th)
    }
  }
  if (method == "slope") {
    # P along the step as the derivative of the dense output applied to the
    # stages' and the end's net production; the end rated again where anything
    # was added.
    B <- slopes_at_zero(e1$state)
    Kn <- vapply(seq_len(N), function(j) kink_K_slope(c(Pst[j, ], e_end$P[j]), Pst[j, ]), 0)
    if (any(Kn != 0)) {
      idx <- 1:(NC * N)
      y1[idx] <- y1[idx] + h * as.vector(B %*% diag(Kn, N))
      CNT$corr <- CNT$corr + sum(Kn != 0)
      e_end <- ev(y1, t + h, th)
    }
  }
  if (method == "dense2") {
    # Nodes whose quartic through the weighted stages and the end changes sign on
    # [0, 1]; for them the integral runs along the cubic through the start, the
    # dense output at 1/3 and 2/3 (two whole evaluations a step) and the end.
    Pq <- cbind(Pst[, c(1, 3, 4, 6)], e_end$P)
    hit <- which(vapply(seq_len(N), function(j) kink_K_end(Pq[j, ], Pst[j, ]) != 0, TRUE))
    if (length(hit)) {
      kk <- cbind(k, e_end$dydt)
      P13 <- ev(y + h * as.vector(kk %*% dense_w(1/3)), t + h / 3, th)$P
      P23 <- ev(y + h * as.vector(kk %*% dense_w(2/3)), t + 2 * h / 3, th)$P
      B <- slopes_at_zero(e1$state)
      Kn <- numeric(N)
      for (j in hit) Kn[j] <- int_cubic(c(Pst[j, 1], P13[j], P23[j], e_end$P[j])) - sum(bw * gfun(Pst[j, ]))
      idx <- 1:(NC * N)
      y1[idx] <- y1[idx] + h * as.vector(B %*% diag(Kn, N))
      CNT$corr <- CNT$corr + length(hit)
      e_end <- ev(y1, t + h, th)
    }
  }
  if (method == "bracket") {
    Pe <- e_end$P
    f <- which(sign(Pe) != sign(Pst[, 1]) & abs(Pe - Pst[, 1]) > 100 * eta)
    if (length(f)) {
      B <- slopes_at_zero(e1$state)
      cs <- c(cc[-5], 1); o <- order(cs); cs <- cs[o]
      for (j in f) {
        p <- c(Pst[j, -5], Pe[j])[o]
        b <- which(sign(p) != sign(p[1]))[1]
        u <- cs[b - 1] + (cs[b] - cs[b - 1]) * p[b - 1] / (p[b - 1] - p[b])
        Pdot <- abs(p[b] - p[b - 1]) / ((cs[b] - cs[b - 1]) * h)
        rows <- (j - 1) * NC + 1:NC
        y1[rows] <- y1[rows] - h^2 * B[, j] * Pdot * Ksharp(u)
      }
      CNT$corr <- CNT$corr + length(f)
      e_end <- ev(y1, t + h, th)
    }
  }
  if (method == "split") {
    f1 <- e_end$dydt
    dense <- function(u) y + h * as.vector(cbind(k, f1) %*% dense_w(u))
    us <- (1:31) / 32
    Pd <- sapply(us, function(u) rates(dense(u), t + u * h, th)$P)  # N x 31, not counted
    s0 <- sign(Pst[, 1])
    hit <- which(apply(cbind(Pst[, -1], e_end$P, Pd) * s0 < 0, 1, any))
    if (length(hit)) {
      m <- 32; hs <- h / m
      for (j in hit) {
        rows <- (j - 1) * NC + 1:NC
        xj <- y[rows]
        f <- function(u, x) { z <- dense(u); z[rows] <- x; ev(z, t + u * h, th)$dydt[rows] }
        for (q in 0:(m - 1)) {
          u0 <- q / m; du <- 1 / m
          a1 <- f(u0, xj)
          a2 <- f(u0 + du / 2, xj + hs / 2 * a1)
          a3 <- f(u0 + du / 2, xj + hs / 2 * a2)
          a4 <- f(u0 + du, xj + hs * a3)
          xj <- xj + hs / 6 * (a1 + 2 * a2 + 2 * a3 + a4)
        }
        y1[rows] <- xj
      }
      CNT$split <- CNT$split + length(hit)
      e_end <- ev(y1, t + h, th)
    }
  }
  list(y = y1, yerr = yerr, e_end = e_end)
}

# The controller: plant's error level atol + rtol (|y| + h|y'|), atol tied.
err_ratio <- function(y, yerr, dydt, h, tol) {
  lev <- 1e-4 * tol + tol * (abs(y) + h * abs(dydt))
  max(abs(yerr) / lev)
}
run_adaptive <- function(th, tol, method = "plain", h0 = 1e-3) {
  t <- 0; y <- TOY$y0; e <- ev(y, t, th); h <- h0
  times <- 0
  while (t < TOY$T - 1e-12) {
    h <- min(h, TOY$T - t)
    s <- ck_step(t, y, h, e, th, method)
    ratio <- err_ratio(y, s$yerr, e$dydt, h, tol)
    if (ratio > 1.1) { h <- h * max(0.2, 0.9 * ratio^(-1/5)); next }
    t <- t + h; y <- s$y; e <- s$e_end; times <- c(times, t)
    if (ratio < 0.5) h <- h * min(5, 0.9 * max(ratio, 1e-10)^(-1/6))
  }
  list(times = times, y = y)
}
lnJ_of <- function(y) { N <- TOY$N; log(sum(matrix(y[1:(NC * N)], nrow = NC)[5, ])) }
replay <- function(times, th, method = "plain") {
  y <- TOY$y0; e <- ev(y, 0, th)
  for (i in 2:length(times)) {
    s <- ck_step(times[i - 1], y, times[i] - times[i - 1], e, th, method)
    y <- s$y; e <- s$e_end
  }
  lnJ_of(y)
}
# Elasticity d lnJ / d ln th_k by central differences on the frozen mesh.
elasticity <- function(times, th, k, method, d = 1e-6) {
  up <- th; up[k] <- th[k] * exp(d); dn <- th; dn[k] <- th[k] * exp(-d)
  (replay(times, up, method) - replay(times, dn, method)) / (2 * d)
}
