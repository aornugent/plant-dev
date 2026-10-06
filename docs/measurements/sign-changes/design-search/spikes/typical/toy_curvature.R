# How much of a crossing's staircase does a closed-form kink correction leave, as
# the curvature of P on the step's scale grows? Pure quadrature on a frozen mesh:
# x' = sigma(sin(2 pi t) - theta), so a crossing's q = P'' h / P' is
# 2 pi theta h / sqrt(1 - theta^2), set by theta at fixed h. Cash-Karp steps of h,
# the mesh shifted by 64 offsets (a tol nudge reshuffles u*). The gradient
# dQ/dtheta by central differences on the frozen mesh; its spread over offsets:
#   plain     nothing
#   one-term  subtract  Jk h^2 psi1(u*),                 Jk the slope jump
#   two-term  also      Jk2 h^3 psi2(u*) / 2,            Jk2 the curvature jump
#   two-term, FD   Jk and Jk2 from one-sided differences of the rate at u* +- d, +-2d
#   cut       two pieces either side of u* (the incumbent's mechanism)
eta <- 1e-4
sigma <- function(P) (P + sqrt(P^2 + eta^2)) / 2
b <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
cc <- c(0, 1/5, 3/10, 3/5, 1, 7/8)
psi1 <- function(u) sum(b * pmax(cc - u, 0)) - (1 - u)^2 / 2
psi2 <- function(u) sum(b * pmax(cc - u, 0)^2) - (1 - u)^3 / 3
quad <- function(g, t, h) h * sum(b * g(t + cc * h))
run <- function(th, h, off, mode, T = 3, d = 0.01) {
  g <- function(t) sigma(sin(2 * pi * t) - th)
  grid <- unique(sort(c(0, seq(off, T, by = h), T)))
  Q <- 0
  for (j in seq_len(length(grid) - 1)) {
    t <- grid[j]; hh <- grid[j + 1] - t
    step <- quad(g, t, hh)
    P0 <- sin(2 * pi * t) - th; P1 <- sin(2 * pi * (t + hh)) - th
    if (mode != "plain" && (P0 < 0) != (P1 < 0)) {
      ts <- uniroot(function(s) sin(2 * pi * s) - th, c(t, t + hh), tol = 1e-15)$root
      u <- (ts - t) / hh
      if (mode == "cut") {
        step <- quad(g, t, ts - t) + quad(g, ts, t + hh - ts)
      } else {
        Pd <- 2 * pi * cos(2 * pi * ts); Pdd <- -4 * pi^2 * sin(2 * pi * ts)
        if (mode == "fd") {   # one-sided differences of the rate itself, in time
          e <- d * hh
          fp <- (-3 * g(ts) + 4 * g(ts + e) - g(ts + 2 * e)) / (2 * e)
          fm <- (3 * g(ts) - 4 * g(ts - e) + g(ts - 2 * e)) / (2 * e)
          gpp <- (g(ts) - 2 * g(ts + e) + g(ts + 2 * e)) / e^2
          gmm <- (g(ts) - 2 * g(ts - e) + g(ts - 2 * e)) / e^2
          J1 <- fp - fm; J2 <- gpp - gmm
        } else {              # exact: sigma' jumps by sign, sigma'' is 0 off the band
          s <- if (Pd > 0) 1 else -1
          J1 <- s * Pd; J2 <- s * Pdd
        }
        step <- step - J1 * hh^2 * psi1(u)
        if (mode != "one") step <- step - J2 * hh^3 * psi2(u) / 2
      }
    }
    Q <- Q + step
  }
  Q
}
grad <- function(th, h, off, mode, dt = 1e-7) (run(th + dt, h, off, mode) - run(th - dt, h, off, mode)) / (2 * dt)
set.seed(2)
h <- 0.05
offs <- runif(64)
cat(sprintf("h = %.2f; q at a crossing = 2 pi theta h / sqrt(1 - theta^2)\n", h))
cat("theta     q   plain-sd   one/plain  two/plain  twoFD/plain  cut/plain\n")
for (th in c(0.05, 0.3, 0.6, 0.8, 0.9, 0.95, 0.98)) {
  q <- 2 * pi * th * h / sqrt(1 - th^2)
  sds <- vapply(c("plain", "one", "two", "fd", "cut"), function(m)
    sd(vapply(offs, function(o) grad(th, h, o * h, m), 0)), 0)
  cat(sprintf("%5.2f %6.3f  %.3e   %.4f     %.4f     %.4f       %.4f\n", th, q, sds[1],
              sds[2] / sds[1], sds[3] / sds[1], sds[4] / sds[1], sds[5] / sds[1]))
}
