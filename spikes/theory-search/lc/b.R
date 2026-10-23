options(digits = 4)
## A. measured closed pair, aligned tournament fit A = D_T Pi D_L, Pi + Pi' = 11'
A <- matrix(c(0.937, 0.722, 0.621, 0.645), 2)
d <- det(A); p <- A[1,1] * A[2,2]
r <- (4 * p + c(-1, 1) * sqrt(16 * p * d)) / (2 * A[2,1])
cat("closed: det", d, " Pi12 roots", A[1,2] / r, " Chesson rho", sqrt(A[1,2] * A[2,1] / p), "\n")
cat("kappa", A[1,2] / r[2] - 0.5, " 1-4k^2", 1 - 4 * (A[1,2] / r[2] - 0.5)^2, "\n")
for (nm in c("open31", "open38")) {
  B <- if (nm == "open31") matrix(c(0.872, 0.853, 0.994, 0.909), 2) else matrix(c(1.091, 0.561, 0.957, 0.516), 2)
  rho2 <- B[1,2] * B[2,1] / (B[1,1] * B[2,2])
  cat(nm, "rho", sqrt(rho2), " equal-offset bound: delta <=", 0.5 / sqrt(rho2) - 0.5, "(at Pi12=1/2)\n")
}
## B. aligned n-species: D Pi stable? (eigs of D Pi, D positive diag)
set.seed(1)
worst <- Inf
for (k in 1:20000) {
  n <- sample(3:6, 1); K <- matrix(0, n, n)
  for (i in 1:(n-1)) for (j in (i+1):n) { x <- runif(1, -0.5, 0.5); K[i,j] <- x; K[j,i] <- -x }
  Pi <- 0.5 + K; D <- diag(exp(rnorm(n)))
  worst <- min(worst, min(Re(eigen(D %*% Pi)$values)))
}
cat("aligned random n=3..6: min Re eig(D Pi) =", worst, "\n")
## two-species aligned slow rate vs kappa^2
for (k in c(0.05, 0.1, 0.25)) { Pi <- matrix(c(.5, .5 - k, .5 + k, .5), 2); cat("kappa", k, "eig", Re(eigen(Pi)$values), " k^2", k^2, "\n") }
## C. fronts. Leaves and sensing as discrete measures on heights; Pi_ij = Pr(Z_j > U_i), ties 1/2
Pr <- function(Uh, Uw, Zh, Zw) sum(outer(Uw, Zw) * (outer(Uh, Zh, "<") + 0.5 * outer(Uh, Zh, "==")))
crown <- function(top, depth, n = 41) seq(top - depth, top, length = n)
mk <- function(top, depth, hf, w, v) { # crown leaves + bank at hf; sensing w on bank
  c <- crown(top, depth); list(Zh = c(c, hf), Zw = c(rep((1 - v) / length(c), length(c)), v),
                                Uh = c(c, hf), Uw = c(rep((1 - w) / length(c), length(c)), w)) }
PiM <- function(sp) { n <- length(sp); M <- matrix(0, n, n)
  for (i in 1:n) for (j in 1:n) M[i,j] <- Pr(sp[[i]]$Uh, sp[[i]]$Uw, sp[[j]]$Zh, sp[[j]]$Zw); M }
cat("single species offsets (w,v): ")
for (w in c(0, .5, .9, 1)) { s <- mk(20, 6, 2, w, 0.02); cat(w, Pr(s$Uh, s$Uw, s$Zh, s$Zw) - .5, "; ") }; cat("\n")
s1 <- mk(20, 6, 2, .9, .02); s2 <- mk(14, 6, 2, .9, .02)
P <- PiM(list(s1, s2)); cat("common front h=2:\n"); print(P); cat("det", det(P), "\n")
s1 <- mk(20, 6, 9, .9, .02); s2 <- mk(14, 6, 2, .9, .02)
P <- PiM(list(s1, s2)); cat("tall sp front 9 (above short crown base 8), short front 2:\n"); print(P); cat("det", det(P), "\n")
s1 <- mk(20, 6, 15, .9, .02); s2 <- mk(14, 6, 2, .9, .02)
P <- PiM(list(s1, s2)); cat("tall front 15 (above short crown top 14):\n"); print(P); cat("det", det(P), "\n")
s1 <- mk(20, 6, 2, .9, .02); s2 <- mk(14, 6, 9, .9, .02)
P <- PiM(list(s1, s2)); cat("reversed: tall front 2, short front 9:\n"); print(P); cat("det", det(P), "\n")
## D. Efron-type three species: leaf at three heights (bank, mid, top), cyclic 5/9
H <- list(c(2, 4, 9), c(1, 6, 8), c(3, 5, 7))
sp3 <- function(w) lapply(H, function(h) { lo <- which.min(h); top <- which.max(h)
  Uw <- rep((1 - abs(w)) / 3, 3); if (w >= 0) Uw[lo] <- Uw[lo] + w else Uw[top] <- Uw[top] - w
  list(Zh = h, Zw = rep(1/3, 3), Uh = h, Uw = Uw) })
lv <- function(A, N0, Tm = 4000, dt = 0.01) { N <- N0; mn <- Inf
  for (s in 1:(Tm / dt)) { N <- N * exp(dt * (1 - A %*% N)); mn <- min(mn, N) }
  c(N, mn) }
for (w in c(0, 0.15, -0.15)) {
  P <- PiM(sp3(w)); e <- eigen(P)$values
  rr <- solve(P, rep(1, 3)); A <- P / outer(rep(1,3), rr) # rescale so N* = 1 with r = 1
  out <- lv(A, c(1.3, 0.8, 1.0))
  cat("Efron w", w, " offsets", round(diag(P) - .5, 3), " Pi12,23,31", round(c(P[1,2], P[2,3], P[3,1]), 3),
      " eig", round(e, 3), " N(T)", round(out[1:3], 3), " minN", signif(out[4], 3), "\n")
}
## E. constant final yield: A_ij = T_i L_j (Pi_ij - pibar_i); total direction null
Pi <- matrix(c(.5, .25, .75, .5), 2); L <- c(1, 2); Tt <- c(1.5, 1); p <- L / sum(L)
pib <- Pi %*% p; Acfy <- diag(Tt) %*% (Pi - pib %*% t(rep(1, 2))) %*% diag(L)
cat("CFY A:\n"); print(Acfy); cat("A %*% 1 (equal ln b shift):", Acfy %*% c(1, 1), " eig", eigen(Acfy)$values, "\n")
