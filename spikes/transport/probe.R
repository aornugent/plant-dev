# Richness against heterogeneity, and how often branching alone stops short of the
# ESS community (the NPMLE).
#
#   Rscript probe.R > probe.txt
source("lib.R")
options(digits = 5, width = 120)

cat("== d = 1: uniform sites on [-R, R] ==\n")
cat(sprintf("%5s | %-26s | %-34s\n", "R", "branching only: n, maxD", "branching + probe: n, probes, maxD"))
for (R in c(2, 3, 4, 6, 8, 12, 16)) {
  Y <- matrix(seq(-R, R, length.out = 601)); K <- rep(1 / 601, 601)
  grid <- matrix(seq(-R - 3, R + 3, by = 0.005))
  e1 <- ecoevo(Y, K)
  D1 <- max(invasion(e1$P, e1$k, phi(grid, Y), K))
  e2 <- assemble(Y, K, grid)
  cat(sprintf("%5.1f | %4d %12.7f          | %4d %4d %12.7f   spacing %.3f\n", R, nrow(e1$S), D1,
              nrow(e2$S), e2$probes, e2$Dmax, mean(diff(sort(e2$S)))))
}

cat("\n== d = 2: sites on a square grid [-R, R]^2 ==\n")
for (R in c(2, 3, 4, 5, 6)) {
  g1 <- seq(-R, R, length.out = 25); Y <- as.matrix(expand.grid(g1, g1)); K <- rep(1 / nrow(Y), nrow(Y))
  s1 <- seq(-R - 2, R + 2, by = 0.1); grid <- as.matrix(expand.grid(s1, s1))
  e1 <- ecoevo(Y, K)
  D1 <- max(invasion(e1$P, e1$k, phi(grid, Y), K))
  e2 <- assemble(Y, K, grid, tol = 1e-5)
  cat(sprintf("R = %3.1f | branching only: %3d species, maxD %.5f | + probe: %3d species, %3d probes, maxD %.6f, species / R^2 = %.3f\n",
              R, nrow(e1$S), D1, nrow(e2$S), e2$probes, e2$Dmax, nrow(e2$S) / R^2))
}
