# A dip's birth under the closed-form correction: P(t) = (t - tm)^2 / s^2 - d on
# one step [0, 1], tm = 0.4, s = 0.3, the dip's depth d rising through 0. Below
# d = 0 there is no zero and no correction; above, a correction at each zero.
# The correction's value as d -> 0+ is the jump at the dip's birth. Rate
# x' = sigma(P); the slope jump read from a stencil of 2 or 3 ratings a side at
# u* +- k e, e = 0.01. Compared with the step's own kink error scale for a fast
# crossing of the same rate, |P'| h^2 / 10.
eta <- 1e-4
sigma <- function(P) (P + sqrt(P^2 + eta^2)) / 2
b <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
cc <- c(0, 1/5, 3/10, 3/5, 1, 7/8)
psi1 <- function(u) sum(b * pmax(cc - u, 0)) - (1 - u)^2 / 2
tm <- 0.4; s <- 0.3; e <- 0.01
slope <- function(g, z, side, k) {
  if (k == 2) { x <- side * e * 1:2; y <- g(z + x); (y[2] - y[1]) / (x[2] - x[1]) }
  else { x <- side * e * 1:3; y <- g(z + x); solve(cbind(1, x, x^2), y)[2] }
}
corr <- function(d, k) {
  g <- function(t) sigma((t - tm)^2 / s^2 - d)
  if (d <= 0) return(0)
  z <- tm + c(-1, 1) * s * sqrt(d)
  sum(vapply(z, function(zz) -(slope(g, zz, 1, k) - slope(g, zz, -1, k)) * psi1(zz), 0))
}
exact_err <- function(d) {      # plain quadrature error of the step for this dip
  g <- function(t) sigma((t - tm)^2 / s^2 - d)
  sum(b * g(cc)) - integrate(g, 0, 1, rel.tol = 1e-12, subdivisions = 2000)$value
}
cat("depth d   width    plain error   correction (2 a side)   correction (3 a side)\n")
for (d in c(1e-1, 1e-2, 1e-3, 1e-4, 1e-5, 1e-6)) {
  w <- 2 * s * sqrt(d)
  cat(sprintf("%7.0e  %.4f   %+.3e      %+.3e              %+.3e\n", d, w, exact_err(d), corr(d, 2), corr(d, 3)))
}
# The two-term version: slope and curvature jumps from the same three ratings a
# side (a quadratic through each side), the curvature term h^3 psi2(u*) / 2 added.
psi2 <- function(u) sum(b * pmax(cc - u, 0)^2) - (1 - u)^3 / 3
corr2 <- function(d) {
  g <- function(t) sigma((t - tm)^2 / s^2 - d)
  if (d <= 0) return(0)
  z <- tm + c(-1, 1) * s * sqrt(d)
  side <- function(zz, sd) { x <- sd * e * 1:3; co <- solve(cbind(1, x, x^2), g(zz + x)); c(co[2], 2 * co[3]) }
  sum(vapply(z, function(zz) { j <- side(zz, 1) - side(zz, -1); -j[1] * psi1(zz) - j[2] * psi2(zz) / 2 }, 0))
}
cat("\ntwo-term, 3 a side: the corrected error (plain error + correction)\n")
for (d in c(1e-1, 1e-2, 1e-3, 1e-4, 1e-5, 1e-6)) {
  cat(sprintf("%7.0e  plain %+.3e  corrected %+.3e\n", d, exact_err(d), exact_err(d) + corr2(d)))
}
