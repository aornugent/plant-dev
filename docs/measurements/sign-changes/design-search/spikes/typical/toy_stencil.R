# The closed-form correction with its jumps read off the rate itself, as TF24
# would have to (no access to d rate / d sigma): three ratings each side of the
# zero, at u* +- k e (k = 1..3, e = 0.01 of the step, outside the turn's band),
# a quadratic through each side extrapolated to the zero gives the slope and
# curvature jumps. Same frozen-mesh setting as toy_curvature.R.
eta <- 1e-4
sigma <- function(P) (P + sqrt(P^2 + eta^2)) / 2
b <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
cc <- c(0, 1/5, 3/10, 3/5, 1, 7/8)
psi1 <- function(u) sum(b * pmax(cc - u, 0)) - (1 - u)^2 / 2
psi2 <- function(u) sum(b * pmax(cc - u, 0)^2) - (1 - u)^3 / 3
quad <- function(g, t, h) h * sum(b * g(t + cc * h))
side <- function(g, ts, e, s) {   # slope and curvature at the zero from one side
  x <- s * e * 1:3; y <- g(ts + x)
  co <- solve(cbind(1, x, x^2), y)
  c(co[2], 2 * co[3])
}
run <- function(th, h, off, mode, T = 3, dfrac = 0.01) {
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
        e <- dfrac * hh
        jm <- side(g, ts, e, +1) - side(g, ts, e, -1)
        step <- step - jm[1] * hh^2 * psi1(u)
        if (mode == "two") step <- step - jm[2] * hh^3 * psi2(u) / 2
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
cat("theta     q   plain-sd   one(st)/plain  two(st)/plain  cut/plain\n")
for (th in c(0.05, 0.3, 0.6, 0.8, 0.9)) {
  q <- 2 * pi * th * h / sqrt(1 - th^2)
  sds <- vapply(c("plain", "one", "two", "cut"), function(m)
    sd(vapply(offs, function(o) grad(th, h, o * h, m), 0)), 0)
  cat(sprintf("%5.2f %6.3f  %.3e   %.4f         %.4f         %.4f\n", th, q, sds[1],
              sds[2] / sds[1], sds[3] / sds[1], sds[4] / sds[1]))
}
