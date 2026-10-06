# K estimates against K_true on the toy's crossing node-steps (model_check.rds
# holds K_true): the integral along a reconstruction of P through accurate
# points, the subtraction always the stages' own sum.
#   lin     start and end
#   dense1  start, the dense output at 1/2, end (quadratic)
#   dense3  start, the dense output at .3, .6, .875, end (quartic)
source("toy.R")
setup()
th0 <- c(2, 0.35, 0.05)
mesh <- run_adaptive(th0, 1e-4, "plain")$times
MC <- readRDS("model_check.rds")
Gint <- function(P) (P * sqrt(P * P + eta * eta) + eta * eta * asinh(P / eta)) / 4
int_pl <- function(u, P) {
  du <- diff(u); a <- P[-length(P)]; b <- P[-1]; d <- b - a
  small <- abs(d) < 1e-9 * (abs(a) + abs(b) + eta)
  sum(du * ifelse(small, gfun((a + b) / 2), (Gint(b) - Gint(a)) / ifelse(small, 1, d)))
}
uf <- seq(0, 1, length.out = 513)
poly_int <- function(nodes, vals) {
  co <- solve(outer(nodes, 0:(length(nodes) - 1), `^`), vals)
  int_pl(uf, as.vector(outer(uf, 0:(length(nodes) - 1), `^`) %*% co))
}
N <- TOY$N; y <- TOY$y0; e <- rates(y, 0, th0); rows <- list()
for (i in 2:length(mesh)) {
  t <- mesh[i - 1]; h <- mesh[i] - t
  k <- matrix(0, length(y), 6); k[, 1] <- e$dydt; Pst <- matrix(0, N, 6); Pst[, 1] <- e$P
  for (s in 2:6) {
    yi <- y + h * as.vector(k[, 1:(s - 1), drop = FALSE] %*% A[s, 1:(s - 1)])
    es <- rates(yi, t + cc[s] * h, th0); k[, s] <- es$dydt; Pst[, s] <- es$P
  }
  y1 <- y + h * as.vector(k %*% bw); e1 <- rates(y1, t + h, th0)
  ch <- which(sign(e1$P) != sign(e$P))
  if (length(ch)) {
    kk <- cbind(k, e1$dydt)
    Pd <- function(u) rates(y + h * as.vector(kk %*% dense_w(u)), t + u * h, th0)$P
    P13 <- Pd(1/3); P23 <- Pd(2/3); P3 <- Pd(0.3); P6 <- Pd(0.6); P875 <- Pd(0.875); P05 <- Pd(0.5)
    for (j in ch) {
      sub <- sum(bw * gfun(Pst[j, ]))
      rows[[length(rows) + 1]] <- data.frame(step = i, node = j, h = h,
        lin = poly_int(c(0, 1/3, 2/3, 1), c(e$P[j], P13[j], P23[j], e1$P[j])) - sub,
        dense1 = poly_int(c(0, 0.5, 1), c(e$P[j], P05[j], e1$P[j])) - sub,
        dense3 = poly_int(c(0, 0.3, 0.6, 0.875, 1), c(e$P[j], P3[j], P6[j], P875[j], e1$P[j])) - sub)
    }
  }
  y <- y1; e <- e1
}
D <- merge(do.call(rbind, rows), MC[, c("step", "node", "Ktrue", "Kend", "Kbr")], by = c("step", "node"))
r <- function(a, b) sqrt(mean((a - b)^2)) / sqrt(mean(a^2))
mb <- function(a, b) mean(b - a) / sqrt(mean(a^2))
for (sel in list(all = rep(TRUE, nrow(D)), long = D$h > 4 / 365, short = D$h <= 4 / 365)) {
  cat(sprintf("n=%d  rms err/rms K_true: endpoint %.3f bracket %.3f dense2 %.3f dense1 %.3f dense3 %.3f | mean bias: endpoint %+.3f dense2 %+.3f dense1 %+.3f dense3 %+.3f\n",
    sum(sel), r(D$Ktrue[sel], D$Kend[sel]), r(D$Ktrue[sel], D$Kbr[sel]), r(D$Ktrue[sel], D$lin[sel]), r(D$Ktrue[sel], D$dense1[sel]),
    r(D$Ktrue[sel], D$dense3[sel]), mb(D$Ktrue[sel], D$Kend[sel]), mb(D$Ktrue[sel], D$lin[sel]), mb(D$Ktrue[sel], D$dense1[sel]), mb(D$Ktrue[sel], D$dense3[sel])))
}
