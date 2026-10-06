# Toy: a pool y' = -k y + b*sigma(P(t)) + g with P(t) = sin(w t + phi) - c and
# sigma the smooth positive part (eta = 1e-4); J = the integral of y. Cash-Karp
# 5th-order steps on a frozen mesh. dJ/dphi moves the crossings, dJ/db does not.
# Spread of each over seven mesh nudges (every step scaled by 1 + d, d in +-5%):
# plain, against the steps that hold a sign change cut into m equal steps.
# Gradients by central differences on each frozen mesh.
eta <- 1e-4
A <- list(numeric(0), 1/5, c(3/40, 9/40), c(3/10, -9/10, 6/5), c(-11/54, 5/2, -70/27, 35/27),
          c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096))
C <- c(0, 1/5, 3/10, 3/5, 1, 7/8)
B <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
sig <- function(p) 0.5 * (p + sqrt(p * p + eta * eta))
k <- 3; w <- 2 * pi; cc <- 0.3; g <- 0.1
run <- function(mesh, phi, b, cuts) {
  f <- function(t, y) -k * y + b * sig(sin(w * t + phi) - cc) + g
  y <- 0; J <- 0; ks <- numeric(6)
  for (i in seq_len(length(mesh) - 1)) {
    t0 <- mesh[i]; t1 <- mesh[i + 1]; m <- cuts[i]
    for (s in seq_len(m)) {
      a <- t0 + (t1 - t0) * (s - 1) / m; h <- (t1 - t0) / m
      for (j in 1:6) {
        yy <- if (j == 1) y else y + h * sum(A[[j]] * ks[seq_len(j - 1)])
        ks[j] <- f(a + C[j] * h, yy)
      }
      ynew <- y + h * sum(B * ks)
      J <- J + h * (y + ynew) / 2   # the same census rule in every arm
      y <- ynew
    }
  }
  J
}
crossing <- function(mesh, phi) { p <- sin(w * mesh + phi) - cc; sign(head(p, -1)) != sign(tail(p, -1)) }
set.seed(1)
Tend <- 12; h0 <- 0.02
base <- c(0, cumsum(h0 * (0.6 + 0.8 * runif(ceiling(Tend / h0 * 1.3)))))
base <- c(base[base < Tend], Tend)
phi0 <- 0.4; b0 <- 1; r <- 1e-4
res <- list()
for (m in c(1, 2, 4)) {
  gp <- gb <- numeric(0)
  for (d in seq(-0.05, 0.05, length.out = 7)) {
    mesh <- base * (1 + d); mesh <- c(mesh[mesh < Tend], Tend)
    cuts <- ifelse(crossing(mesh, phi0), m, 1)
    gp <- c(gp, (run(mesh, phi0 + r, b0, cuts) - run(mesh, phi0 - r, b0, cuts)) / (2 * r))
    gb <- c(gb, (run(mesh, phi0, b0 * (1 + r), cuts) - run(mesh, phi0, b0 * (1 - r), cuts)) / (2 * r))
  }
  res[[m]] <- c(sd(gp), sd(gb), mean(gp), mean(gb))
  cat(sprintf("m=%d: sd dJ/dphi %.3e  sd dJ/dlnb %.3e  (means %.6f %.6f); crossing steps %d of %d\n",
              m, sd(gp), sd(gb), mean(gp), mean(gb), sum(crossing(base, phi0)), length(base) - 1))
}
for (m in c(2, 4)) cat(sprintf("m=%d: sd falls %.2fx for phi (moves the crossing), %.2fx for b (does not)\n",
                               m, res[[1]][1] / res[[m]][1], res[[1]][2] / res[[m]][2]))
