options(digits = 4)
## 1. two crowns of leaf-area depth X each (uniform density), offset s in units of crown length; shared light
pair <- function(gamma, s, X = 2, th0 = 30, n = 4001) {
  z <- seq(-1, 1 + s + 1, length = n); dz <- diff(z)[1]
  q1 <- ifelse(z >= 0 & z <= 1, X, 0); q2 <- ifelse(z >= s & z <= 1 + s, X, 0)
  Lam <- rev(cumsum(rev(q1 + q2))) * dz; I <- exp(-Lam)
  V <- I^gamma; th <- th0 * I / V; e <- V * th / (1 + th)^2   # dP/dlnI at fixed V
  u <- list(q1 * e, q2 * e); q <- list(q1, q2)
  G <- lapply(q, function(qq) { g <- rev(cumsum(rev(qq))) * dz; g / max(g) })  # Pr(Z_j > z)
  P <- matrix(0, 2, 2); for (i in 1:2) for (j in 1:2) P[i,j] <- sum(u[[i]] * G[[j]]) / sum(u[[i]])
  P
}
cat("rows gamma; cols offset s; entries Chesson rho (Pi-only)\n")
ss <- c(0.25, 0.5, 0.75, 1, 1.5)
for (g in c(0, 0.25, 0.5, 0.75, 1)) {
  r <- sapply(ss, function(s) { P <- pair(g, s); sqrt(P[1,2] * P[2,1] / (P[1,1] * P[2,2])) })
  cat(g, round(r, 3), "\n")
}
cat("aligned reference (u = q, no physiology):\n")
pairA <- function(s) { P <- pair(0, s, th0 = 1e-9); sqrt(P[1,2]*P[2,1]/(P[1,1]*P[2,2])) }
cat(round(sapply(ss, pairA), 3), "\n")
## 2. Efron toy, fixed rescaling A = P diag(r), N* = 1
Pr <- function(Uh, Uw, Zh, Zw) sum(outer(Uw, Zw) * (outer(Uh, Zh, "<") + 0.5 * outer(Uh, Zh, "==")))
H <- list(c(2, 4, 9), c(1, 6, 8), c(3, 5, 7))
PiE <- function(w) { sp <- lapply(H, function(h) { lo <- which.min(h); Uw <- rep((1 - w) / 3, 3); Uw[lo] <- Uw[lo] + w
  list(h = h, Uw = Uw) }); M <- matrix(0, 3, 3)
  for (i in 1:3) for (j in 1:3) M[i,j] <- Pr(sp[[i]]$h, sp[[i]]$Uw, sp[[j]]$h, rep(1/3, 3)); M }
PiP <- function(dd) { M <- PiE(0); M + diag(dd, 3) }  # purely private offset
lv <- function(A, N0, Tm = 3000, dt = 0.01) { N <- N0; mn <- Inf
  for (k in 1:(Tm / dt)) { N <- N * exp(dt * (1 - A %*% N)); mn <- min(mn, N) }; c(N, mn) }
for (case in list(list("bank w", 0.3, PiE(0.3)), list("bank w", 0.6, PiE(0.6)), list("private d", 0.05, PiP(0.05)),
                  list("private d", -0.02, PiP(-0.02)))) {
  P <- case[[3]]; rr <- solve(P, rep(1, 3)); A <- P %*% diag(rr)
  out <- lv(A, c(1.3, 0.8, 1.0))
  cat(case[[1]], case[[2]], " diag-1/2", round(diag(P) - .5, 3), " r>0", all(rr > 0),
      " eig(A)", round(eigen(A)$values, 4), " N(T)", round(out[1:3], 3), " minN", signif(out[4], 3), "\n")
}
## 3. first-order two-species budget: det = k^2 + (p1+p2)/2 + k(m12 - m21)
P <- pair(1, 0.5); Pal <- pair(0, 0.5, th0 = 1e-9)
m <- P - Pal; k <- Pal[1,2] - 0.5
cat("aligned Pi12", Pal[1,2], " m", round(m, 4), "\n")
cat("det exact", det(P), " budget", k^2 + ((m[1,1]-m[1,2]) + (m[2,2]-m[2,1]))/2 + k*(m[1,2]-m[2,1]), "\n")
## 4. age term without separability: Cauchy-Binet sign
ages <- 1:40; L1 <- exp(-((ages - 8)/6)^2); L2 <- exp(-((ages - 25)/9)^2)
for (lag in c(0, -6, -15)) {  # elasticity trajectories led by 'lag' years
  T1 <- exp(-((ages - 8 - lag)/6)^2); T2 <- exp(-((ages - 25 - lag)/9)^2)
  Xi <- sum(T1*L2)*sum(T2*L1)/(sum(T1*L1)*sum(T2*L2)); cat("lag", lag, " age cross-ratio Xi", round(Xi, 4), "\n") }
T1 <- exp(-((ages - 3)/3)^2); T2 <- exp(-((ages - 3)/3)^2)
cat("both read at establishment (age 3): Xi", round(sum(T1*L2)*sum(T2*L1)/(sum(T1*L1)*sum(T2*L2)), 4), "\n")
