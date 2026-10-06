# Toy: one node, x' = sigma(P) - 0.5 x, P = sin(2 pi t) + 0.3 x - theta, sigma
# TF24's smooth positive part (eta 1e-4), so every crossing has kappa >> 1.
# Cash-Karp on a frozen mesh of step h, shifted by an offset (a stand-in for a
# tol nudge: it reshuffles every crossing's u*). Q = x(T). The gradient dQ/dtheta
# by central differences on the frozen mesh. Three treatments of a step whose
# ends' P differ in sign:
#   plain      nothing
#   correct    the leading kink error removed: x_end -= Jk h^2 psi(u*), with the
#              rate's slope jump Jk = F_sigma |dP/dt| known exactly (F_sigma = 1)
#   cut        the node integrated in two pieces either side of the zero of P on
#              the dense output (the incumbent's mechanism)
# Reported: the gradient's spread over 32 offsets (sd), against its converged value.
eta <- 1e-4
sigma <- function(P) (P + sqrt(P^2 + eta^2)) / 2
Pof <- function(t, x, th) sin(2 * pi * t) + 0.3 * x - th
f <- function(t, x, th) sigma(Pof(t, x, th)) - 0.5 * x
ah <- c(1/5, 3/10, 3/5, 1, 7/8)
A <- list(c(1/5), c(3/40, 9/40), c(3/10, -9/10, 6/5), c(-11/54, 5/2, -70/27, 35/27),
          c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096))
b <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
cc <- c(0, ah)
dw <- rbind(c(1, 0, 0, 0, 0, 0, 0),
            c(-156473/57792, 0, 1159825/332304, 14725/60544, 5301/38528, -202836/76153, 3/2),
            c(729889/260064, 0, -8030425/1495368, 290425/817344, -5301/19264, 493736/76153, -4),
            c(-24797/24768, 0, 2275475/996912, -19225/49536, 5301/38528, -3492/989, 5/2))
psi <- function(u) sum(b * pmax(cc - u, 0)) - (1 - u)^2 / 2
ck <- function(t, x, h, th) {
  k <- numeric(6); k[1] <- f(t, x, th)
  for (i in 2:6) k[i] <- f(t + ah[i - 1] * h, x + h * sum(A[[i - 1]] * k[1:(i - 1)]), th)
  list(x = x + h * sum(b * k), k = k)
}
dense <- function(u, x0, h, k, kend) {
  w <- vapply(1:7, function(i) (((dw[4, i] * u + dw[3, i]) * u + dw[2, i]) * u + dw[1, i]) * u, 0)
  x0 + h * sum(w * c(k, kend))
}
locate <- function(t, x0, h, k, kend, th, v0, v1) {
  a <- 0; bb <- 1; va <- v0; vb <- v1
  for (it in 1:200) {
    u <- (a * vb - bb * va) / (vb - va)
    v <- Pof(t + u * h, dense(u, x0, h, k, kend), th)
    if (abs(v) < 1e-14 || bb - a < 1e-15) break
    if ((v < 0) == (vb < 0)) { bb <- u; vb <- v; va <- va / 2 } else { a <- u; va <- v; vb <- vb / 2 }
  }
  u
}
run <- function(th, h, off, T = 2, mode = "plain") {
  grid <- unique(sort(c(0, seq(off, T, by = h), T)))
  x <- 0.2
  for (j in seq_len(length(grid) - 1)) {
    t <- grid[j]; hh <- grid[j + 1] - t
    s <- ck(t, x, hh, th)
    if (mode != "plain") {
      v0 <- Pof(t, x, th); v1 <- Pof(t + hh, s$x, th)
      if ((v0 < 0) != (v1 < 0)) {
        kend <- f(t + hh, s$x, th)
        u <- locate(t, x, hh, s$k, kend, th, v0, v1)
        if (mode == "cut") {
          p1 <- ck(t, x, u * hh, th)
          s$x <- ck(t + u * hh, p1$x, (1 - u) * hh, th)$x
        } else {
          xs <- dense(u, x, hh, s$k, kend)
          dPdt <- 2 * pi * cos(2 * pi * (t + u * hh)) + 0.3 * f(t + u * hh, xs, th)
          s$x <- s$x - abs(dPdt) * hh^2 * psi(u)
        }
      }
    }
    x <- s$x
  }
  x
}
grad <- function(th, h, off, mode, d = 1e-6) (run(th + d, h, off, mode = mode) - run(th - d, h, off, mode = mode)) / (2 * d)
th0 <- 0.3
ref <- grad(th0, 1e-3, 0, "cut")
cat(sprintf("converged dQ/dtheta (cut, h = 1e-3): %.10f\n", ref))
set.seed(1)
offs <- runif(32)
for (h in c(0.1, 0.05, 0.025)) {
  for (mode in c("plain", "correct", "cut")) {
    g <- vapply(offs, function(o) grad(th0, h, o * h, mode), 0)
    cat(sprintf("h %.3f %-8s spread (sd over 32 offsets) %.3e  mean error %+.3e  max |error| %.3e\n",
                h, mode, sd(g), mean(g) - ref, max(abs(g - ref))))
  }
}
