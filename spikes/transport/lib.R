# The lottery metacommunity, its rate-distortion objective and eco-evolutionary
# assembly, shared by rd.R and probe.R.

lse <- function(x) { m <- max(x); m + log(sum(exp(x - m))) }
# A kernel W_js = exp(phi_js) held as exp(phi - cm_s) and cm_s, the column maximum; a
# shift common to every species at one site cancels in the lottery.
kernel <- function(lW, cm = apply(lW, 2, max)) list(W = exp(sweep(lW, 2, cm)), cm = cm)
mix <- function(P, k) as.vector(crossprod(k$W, P))
loglik <- function(P, k, K) sum(K * (log(mix(P, k)) + k$cm))
lottery <- function(P, k, K) P * as.vector(k$W %*% (K / mix(P, k)))
coupling <- function(P, k, K) k$W * outer(P, K / mix(P, k))
mutual_info <- function(pi) {
  r <- rowSums(pi); c <- colSums(pi); z <- pi > 0
  sum(pi[z] * log(pi[z] / outer(r, c)[z]))
}
equilibrate <- function(P, k, K, n = 20000, tol = 1e-13) {
  for (i in seq_len(n)) {
    P2 <- lottery(P, k, K)
    if (max(abs(P2 - P)) < tol) return(P2)
    P <- P2
  }
  P2
}
# regional invasion fitness of every row of lW_inv against pool P on kernel k
invasion <- function(P, k, lW_inv, K)
  as.vector(exp(sweep(lW_inv, 2, k$cm)) %*% (K / mix(P, k)))

# phi(S, y) = -|S|^2/(2c) + S.y: a quadratic frontier, sensitivity S, field y.
cfr <- 1
phi <- function(S, Y) S %*% t(Y) - rowSums(S^2) / (2 * cfr)

# Ecology (lottery) and evolution (each species to the centroid c E[y | j], the
# canonical equation's fixed point) to convergence.
settle <- function(S, P, Y, K, iters = 3000) {
  for (it in 1:iters) {
    k <- kernel(phi(S, Y))
    P <- equilibrate(P, k, K, n = 50)
    pi <- coupling(P, k, K)
    S2 <- cfr * (pi %*% Y) / rowSums(pi)
    if (max(abs(S2 - S)) < 1e-11) break
    S <- S2
  }
  k <- kernel(phi(S, Y)); P <- equilibrate(P, k, K)
  # merge atoms that have converged onto one another, drop the extinct
  keep <- P > 1e-9; S <- S[keep, , drop = FALSE]; P <- P[keep]
  i <- 1
  while (i < nrow(S)) {
    near <- which(sqrt(colSums((t(S) - S[i, ])^2)) < 1e-4)
    near <- near[near > i]
    if (length(near)) {
      S[i, ] <- colSums(S[c(i, near), , drop = FALSE] * P[c(i, near)]) / sum(P[c(i, near)])
      P[i] <- sum(P[c(i, near)]); S <- S[-near, , drop = FALSE]; P <- P[-near]
    }
    i <- i + 1
  }
  list(S = S, P = P / sum(P), k = kernel(phi(S, Y)))
}
# Split every species whose within-species field covariance has c lambda_max > 1.
branch <- function(e, Y, K, delta) {
  pi <- coupling(e$P, e$k, K); split <- NULL; dirs <- list()
  for (j in seq_len(nrow(e$S))) {
    w <- pi[j, ] / sum(pi[j, ]); m <- colSums(Y * w)
    ev <- eigen(crossprod(sweep(Y, 2, m) * sqrt(w)), symmetric = TRUE)
    if (cfr * ev$values[1] > 1 + 1e-6) { split <- c(split, j); dirs[[length(split)]] <- ev$vectors[, 1] }
  }
  if (!length(split)) return(NULL)
  Dm <- do.call(rbind, dirs); S <- e$S; P <- e$P
  list(S = rbind(S[-split, , drop = FALSE], S[split, , drop = FALSE] - delta * Dm,
                 S[split, , drop = FALSE] + delta * Dm),
       P = c(P[-split], P[split] / 2, P[split] / 2))
}
# Adaptive dynamics with branching only.
ecoevo <- function(Y, K, delta = 1e-3, rounds = 80) {
  e <- settle(matrix(colSums(Y * K) * cfr, 1), 1, Y, K)
  for (r in seq_len(rounds)) {
    b <- branch(e, Y, K, delta)
    if (is.null(b)) break
    e <- settle(b$S, b$P, Y, K)
  }
  e
}
# Branching plus a global probe: when nothing branches, add the strategy on the grid
# with the largest regional invasion fitness, until max D <= 1 + tol.
assemble <- function(Y, K, grid, delta = 1e-3, tol = 1e-6, rounds = 200) {
  e <- ecoevo(Y, K, delta)
  probes <- 0
  for (r in seq_len(rounds)) {
    D <- invasion(e$P, e$k, phi(grid, Y), K)
    if (max(D) <= 1 + tol) break
    e <- settle(rbind(e$S, grid[which.max(D), , drop = FALSE]), c(e$P, 1e-3), Y, K)
    probes <- probes + 1
    b <- branch(e, Y, K, delta)
    while (!is.null(b)) { e <- settle(b$S, b$P, Y, K); b <- branch(e, Y, K, delta) }
  }
  e$Dmax <- max(invasion(e$P, e$k, phi(grid, Y), K)); e$probes <- probes
  e
}
