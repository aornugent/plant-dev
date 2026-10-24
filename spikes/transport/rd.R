# Assembly as rate-distortion: numerical checks of docs/review/assembly-transport.md.
#
# A lottery metacommunity: sites s with area K_s, a global seed pool P_j, and
# per-seed lifetime success W_js = exp(phi_js). Each generation every site is
# filled by lottery among arriving seeds, n_js = K_s P_j W_js / sum_k P_k W_ks,
# and the next pool is P'_j = sum_s n_js.
#
#   Rscript rd.R > rd.txt
#
# Richness with a global probe is probe.R; the node schedule is schedule.R.
set.seed(1)
options(digits = 5, width = 120)

source("lib.R")

cat("== T1. The lottery is Blahut-Arimoto for rate-distortion ==\n")
J <- 8; N <- 30
lW <- matrix(rnorm(J * N, sd = 1.5), J, N)
K <- runif(N); K <- K / sum(K)
k <- kernel(lW)
P <- equilibrate(rep(1 / J, J), k, K, n = 200000, tol = 1e-15)
nll <- function(z) -loglik(exp(z) / sum(exp(z)), k, K)
opt <- optim(rep(0, J), nll, method = "BFGS", control = list(reltol = 1e-15, maxit = 5000))
pi <- coupling(P, k, K)
cat(sprintf("L(lottery) = %.12f   L(BFGS) = %.12f\n", loglik(P, k, K), -opt$value))
cat(sprintf("<pi, phi> - I(pi) = %.12f\n", sum(pi * lW) - mutual_info(pi)))
cat(sprintf("species marginal of pi equals P: %.2e\n", max(abs(rowSums(pi) - P))))
u <- rep(1, J); v <- rep(1, N); Wk <- exp(lW)
for (i in 1:20000) { u <- P / (Wk %*% v); v <- K / (t(Wk) %*% u) }
pis <- Wk * outer(as.vector(u), as.vector(v))
cat(sprintf("max |pi_lottery - pi_sinkhorn| = %.2e\n", max(abs(pis - pi))))
cat("regional invasion fitness D_j (1 on the support, <= 1 off it):\n")
print(rbind(P = P, D = invasion(P, k, lW, K)))
# a site-common shift of phi leaves P and pi unchanged
k2 <- kernel(sweep(lW, 2, rnorm(N, sd = 3), "+"))
P2 <- equilibrate(rep(1 / J, J), k2, K, n = 200000, tol = 1e-15)
cat(sprintf("site-common shift of phi (sd 3): max |dP| = %.2e\n", max(abs(P2 - P))))

cat("\n== T2. Eco-evolution: the ESS community is the NPMLE; branching is codebook splitting ==\n")
cat("Uniform sites on [-R, R]: one species branches when c Var(y) = c R^2/3 > 1, R_c = sqrt(3) = 1.732\n")
cat("maxD: the largest regional invasion fitness over a fine grid of strategies (<= 1 certifies the NPMLE)\n")
cat(sprintf("%5s %8s %10s %12s\n", "R", "species", "species/R", "maxD"))
for (R in c(1.5, 1.7, 1.75, 2, 3, 4, 6, 8, 12)) {
  Y <- matrix(seq(-R, R, length.out = 601)); K <- rep(1 / 601, 601)
  e <- ecoevo(Y, K)
  grid <- matrix(seq(-R - 3, R + 3, by = 0.005))
  Dmax <- max(invasion(e$P, e$k, phi(grid, Y), K))
  cat(sprintf("%5.2f %8d %10.3f %12.8f\n", R, nrow(e$S), nrow(e$S) / R, Dmax))
}
cat("Pitchfork: past R_c the two species separate as sqrt(c Var - 1)\n")
for (R in c(1.74, 1.76, 1.80, 1.90, 2.0)) {
  Y <- matrix(seq(-R, R, length.out = 601)); K <- rep(1 / 601, 601)
  e <- ecoevo(Y, K, delta = 1e-4, rounds = 2)
  cat(sprintf("R = %.2f  c Var - 1 = %.4f  species = %d  separation = %.4f  separation / sqrt(c Var - 1) = %.3f\n",
              R, R^2 / 3 - 1, nrow(e$S), diff(range(e$S)), diff(range(e$S)) / sqrt(R^2 / 3 - 1)))
}

cat("\n== T4. Inverse: composition identifies field contrasts between sites ==\n")
J <- 6; N <- 25; d <- 2
Sj <- matrix(rnorm(J * d), J, d); a <- -rowSums(Sj^2) / 2
ytrue <- matrix(rnorm(N * d), N, d)
Pj <- rep(1 / J, J)
eta <- outer(log(Pj) + a, rep(1, N)) + Sj %*% t(ytrue)
q <- exp(eta - rep(apply(eta, 2, lse), each = J))
counts <- apply(q, 2, function(p) rmultinom(1, 400, p))
fit_site <- function(n_s, alpha) {
  f <- function(y) { e <- alpha + Sj %*% y; -(sum(n_s * e) - sum(n_s) * lse(e)) }
  optim(rep(0, d), f, method = "BFGS")$par
}
yhat <- t(apply(counts, 2, fit_site, alpha = log(Pj) + a))
cat(sprintf("pool and frontier known: rms(yhat - y) = %.3f   (field sd 1, 400 individuals a site)\n",
            sqrt(mean((yhat - ytrue)^2))))
joint <- function(par) {
  al <- par[1:J]; Y <- matrix(par[-(1:J)], N, d)
  e <- outer(al, rep(1, N)) + Sj %*% t(Y)
  -sum(counts * e) + sum(colSums(counts) * apply(e, 2, lse))
}
o <- optim(rep(0, J + N * d), joint, method = "BFGS", control = list(maxit = 5000, reltol = 1e-12))
Yj <- matrix(o$par[-(1:J)], N, d)
shift <- colMeans(Yj - ytrue)
cat(sprintf("pool unknown: rms after removing one shift common to all sites = %.3f; the shift = (%.2f, %.2f)\n",
            sqrt(mean((sweep(Yj, 2, shift) - ytrue)^2)), shift[1], shift[2]))

cat("\n== T5. Field feedback: symmetric competition keeps one equilibrium; skew adds rotation ==\n")
# phi_js = phi0_js - (A p_s)_j, with p_s the composition at site s.
J <- 5; N <- 12
phi0 <- matrix(rnorm(J * N), J, N); K <- rep(1 / N, N)
B <- matrix(rnorm(J * J), J)
Asym <- crossprod(B) / J; Askew <- (B - t(B)) / 2
run_fb <- function(A, P0, gens = 6000, damp = 0.2) {
  P <- P0; Pp <- matrix(1 / J, J, N); traj <- numeric(gens)
  for (g in 1:gens) {
    k <- kernel(phi0 - A %*% Pp)
    pi <- coupling(P, k, K)
    Pp <- (1 - damp) * Pp + damp * sweep(pi, 2, K, "/")
    P <- (1 - damp) * P + damp * rowSums(pi)
    traj[g] <- P[1]
  }
  list(P = P, osc = diff(range(tail(traj, 500))))
}
for (nm in c("symmetric", "symmetric + 2 skew", "symmetric + 8 skew")) {
  A <- switch(nm, "symmetric" = Asym, "symmetric + 2 skew" = Asym + 2 * Askew,
              "symmetric + 8 skew" = Asym + 8 * Askew)
  runs <- replicate(8, { P0 <- runif(J); run_fb(A, P0 / sum(P0)) }, simplify = FALSE)
  ends <- sapply(runs, `[[`, "P")
  cat(sprintf("%-20s spread across 8 starts = %.2e   late oscillation = %.2e\n", nm,
              max(apply(ends, 1, function(x) diff(range(x)))), max(sapply(runs, `[[`, "osc"))))
}

