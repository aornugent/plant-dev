options(digits = 4)
## acclimation robustness: rho(gamma)/rho(aligned) over X, th0, s
pair <- function(e_fun, s, X) { n <- 3001
  z <- seq(-1, 1 + s + 1, length = n); dz <- diff(z)[1]
  q1 <- ifelse(z >= 0 & z <= 1, X, 0); q2 <- ifelse(z >= s & z <= 1 + s, X, 0)
  I <- exp(-rev(cumsum(rev(q1 + q2))) * dz); e <- e_fun(I)
  u <- list(q1 * e, q2 * e); q <- list(q1, q2)
  G <- lapply(q, function(qq) { g <- rev(cumsum(rev(qq))) * dz; g / max(g) })
  P <- matrix(0, 2, 2); for (i in 1:2) for (j in 1:2) P[i,j] <- sum(u[[i]] * G[[j]]) / sum(u[[i]])
  sqrt(P[1,2]*P[2,1]/(P[1,1]*P[2,2])) }
ef <- function(g, th0) function(I) { V <- I^g; th <- th0 * I / V; V * th / (1 + th)^2 }
cat("X th0 s | rho aligned | rho gamma=0, .5, 1\n")
for (X in c(1, 2, 4)) for (th0 in c(3, 30, 300)) for (s in c(0.25, 0.5)) {
  ra <- pair(function(I) 1, s, X)
  cat(X, th0, s, "|", round(ra, 3), "|", round(sapply(c(0, .5, 1), function(g) pair(ef(g, th0), s, X)), 3), "\n") }
## TF24 reserve knife: (1-G(r))(1-r) = (sqrt(x^2+1)-x)^2 r, G = logistic((r-0.1)/0.1); mu = 0.01 + 5.5 exp(-20 r)
rstar <- function(x) uniroot(function(r) (1 - plogis((r - 0.1)/0.1))*(1 - r) - (sqrt(x^2+1) - x)^2 * r, c(1e-9, 1 - 1e-9), tol = 1e-12)$root
mu <- function(x) 0.01 + 5.5 * exp(-20 * sapply(x, rstar))
cat("x:", c(-2, -1, 0, 1, 2), " mu:", round(mu(c(-2, -1, 0, 1, 2)), 3), "\n")
xs <- seq(-6, 6, by = 0.01); ms <- mu(xs)
d1 <- diff(ms)/0.01; d2 <- diff(d1)/0.01
cat("mu'(0)", round(d1[which.min(abs(xs[-1] - 0.005))], 3), " mu''(0)", round(d2[which.min(abs(xs[-(1:2)]))], 3), "\n")
infl <- xs[-(1:2)][which(diff(sign(d2)) != 0)]; cat("inflection(s) of mu at x =", round(infl, 2), "\n")
gh <- function(f, m, s, k = 801) { z <- seq(-6, 6, length = k); w <- dnorm(z); w <- w/sum(w); sum(w * f(m + s*z)) }
muf <- approxfun(xs, ms, rule = 2)
for (kap in c(0.03, 0.1, 0.3)) {
  x0 <- uniroot(function(x) muf(x) - kap, c(-3, 6))$root
  cat("kappa", kap, " front x0", round(x0, 3), " mu''(x0)", round(approx(xs[-(1:2)], d2, x0)$y, 3), "\n")
  for (s in c(0.3, 1, 3)) {
    xs0 <- uniroot(function(x) gh(muf, x, s) - kap, c(-3, 8))$root
    g0 <- -(gh(muf, x0 + 1e-3, 0) - gh(muf, x0 - 1e-3, 0))/2e-3
    gs <- -(gh(muf, xs0 + 1e-3, s) - gh(muf, xs0 - 1e-3, s))/2e-3
    cat("   sigma/eps", s, " Jensen excess at x0:", round(gh(muf, x0, s) - kap, 4),
        " front shift to keep kappa:", round(xs0 - x0, 3), " gain |dEmu/dx| ratio (noisy/quiet):", round(gs/g0, 3), "\n") } }
