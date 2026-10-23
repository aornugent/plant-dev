options(digits = 4)
pair <- function(mode, s, X = 2, th0 = 30, gamma = 0, n = 4001) {
  z <- seq(-1, 1 + s + 1, length = n); dz <- diff(z)[1]
  q1 <- ifelse(z >= 0 & z <= 1, X, 0); q2 <- ifelse(z >= s & z <= 1 + s, X, 0)
  Lam <- rev(cumsum(rev(q1 + q2))) * dz; I <- exp(-Lam)
  V <- I^gamma; th <- th0 * I / V
  e <- switch(mode, aligned = rep(1, n), phys = V * th / (1 + th)^2)
  u <- list(q1 * e, q2 * e); q <- list(q1, q2)
  G <- lapply(q, function(qq) { g <- rev(cumsum(rev(qq))) * dz; g / max(g) })
  P <- matrix(0, 2, 2); for (i in 1:2) for (j in 1:2) P[i,j] <- sum(u[[i]] * G[[j]]) / sum(u[[i]]); P
}
rho <- function(P) sqrt(P[1,2]*P[2,1]/(P[1,1]*P[2,2]))
for (s in c(0.25, 0.5, 0.75)) {
  Pa <- pair("aligned", s); cat("\ns", s, " aligned Pi", round(c(Pa), 3), " rho", round(rho(Pa), 3), " kappa", round(Pa[1,2]-.5, 3), "\n")
  for (g in c(0, 0.5, 1)) { P <- pair("phys", s, gamma = g); m <- P - Pa
    cat(" gamma", g, " Pi", round(c(P), 3), " delta", round(diag(m), 3), " m12,m21", round(c(m[1,2], m[2,1]), 3),
        " private p", round(c(m[1,1]-m[1,2], m[2,2]-m[2,1]), 3), " rho", round(rho(P), 3), "\n") }
}
# isolate: perturb only species 2 (taller) sensing or only species 1
cat("\nwhich species' offset matters (s=0.5): top-weighted sensing applied to one species only\n")
one <- function(which, s = 0.5, X = 2, n = 4001) {
  z <- seq(-1, 1 + s + 1, length = n); dz <- diff(z)[1]
  q1 <- ifelse(z >= 0 & z <= 1, X, 0); q2 <- ifelse(z >= s & z <= 1 + s, X, 0)
  I <- exp(-rev(cumsum(rev(q1 + q2))) * dz)
  e1 <- if (which %in% c(1, 3)) I else 1; e2 <- if (which %in% c(2, 3)) I else 1
  u <- list(q1 * e1, q2 * e2); q <- list(q1, q2)
  G <- lapply(q, function(qq) { g <- rev(cumsum(rev(qq))) * dz; g / max(g) })
  P <- matrix(0, 2, 2); for (i in 1:2) for (j in 1:2) P[i,j] <- sum(u[[i]] * G[[j]]) / sum(u[[i]]); P }
for (w in 0:3) cat(" top-weighted on", c("none", "short", "tall", "both")[w+1], " rho", round(rho(one(w)), 3), " Pi", round(c(one(w)), 3), "\n")
