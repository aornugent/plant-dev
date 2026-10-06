# slope+ : P-hat = the dense output's derivative over the seven values, plus a
# least-squares fit to the inner stages' residuals of two shapes that integrate to
# zero over [0, 1] and vanish at both ends, so P-hat keeps its ends and its
# integral (the step's own sum). Offline on the saved TF24 rows.
source("/home/user/plant-dev/harness/ark436.R", local = (tab <- new.env()))
BCK4 <- tab$BCK4; bw <- tab$bCK; cc <- tab$cCK; eta <- 1e-4
gfun <- function(P) 0.5 * sqrt(P * P + eta * eta)
Gint <- function(P) (P * sqrt(P * P + eta * eta) + eta * eta * asinh(P / eta)) / 4
uf <- seq(0, 1, length.out = 513)
int_pl <- function(P) { a <- P[-length(P)]; b <- P[-1]; d <- b - a; small <- abs(d) < 1e-9 * (abs(a) + abs(b) + eta)
  sum(diff(uf) * ifelse(small, gfun((a + b) / 2), (Gint(b) - Gint(a)) / ifelse(small, 1, d))) }
wslope <- function(u) as.vector(colSums(BCK4 * ((1:4) * u^(0:3))))
WS <- sapply(uf, wslope); WSc <- sapply(cc, wslope)      # 7 x 513, 7 x 6
psi <- function(u) cbind(u * (1 - u) * (u^2 - u + 1/5), u^2 * (1 - u)^2 * (u - 1/2))
inner <- c(2, 3, 4, 6)
X <- psi(cc[inner]); Fit <- solve(crossprod(X), t(X))   # 2 x 4
Kplus <- function(P7) {
  Pst <- P7[1:6]
  res <- Pst[inner] - as.vector(P7 %*% WSc)[inner]
  ab <- as.vector(Fit %*% res)
  P <- as.vector(P7 %*% WS) + as.vector(psi(uf) %*% ab)
  int_pl(P) - sum(bw * gfun(Pst))
}
cat("check: integrals of the two shapes:", signif(colSums(psi(uf)[-1, ] + psi(uf)[-513, ]) / 2 / 512, 3), "\n")
D <- readRDS("tf24_K_40.rds")
D$Kplus <- apply(D[, c("P1", "P2", "P3", "P4", "P5", "P6", "Pe")], 1, function(v) Kplus(as.numeric(v)))
r <- function(a, b) sqrt(mean((a - b)^2)) / sqrt(mean(a^2))
for (lab in c("all", "t < 29.3", "t > 29.3")) {
  sel <- switch(lab, all = rep(TRUE, nrow(D)), "t < 29.3" = D$t < 29.3, "t > 29.3" = D$t > 29.3)
  cat(sprintf("TF24 %-9s n=%5d  slope %.3f  slope+ %.3f\n", lab, sum(sel), r(D$Kd[sel], D$Kslope[sel]), r(D$Kd[sel], D$Kplus[sel])))
}
saveRDS(D, "tf24_K_40_plus.rds")
