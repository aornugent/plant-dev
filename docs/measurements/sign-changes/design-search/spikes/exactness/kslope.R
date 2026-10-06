# K along the derivative of Cash-Karp's dense output applied to the stage values of
# P and the end's P (no rating beyond the end), against K_true.
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
Wd <- sapply(uf, function(u) as.vector(colSums(BCK4 * ((1:4) * u^(0:3)))))   # 7 x 513, d w / du
cat("check: slope weights at u=0:", round(Wd[, 1], 6), " at u=1:", round(Wd[, 513], 6), "\n")
cat("check: integral of slope weights over [0,1] (should be b, 0):", round(rowSums(Wd[, -1] + Wd[, -513]) / 2 / 512, 6), "\n")
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
  for (j in ch) {
    Phat <- as.vector(c(Pst[j, ], e1$P[j]) %*% Wd)
    rows[[length(rows) + 1]] <- data.frame(step = i, node = j, Kslope = int_pl(uf, Phat) - sum(bw * gfun(Pst[j, ])))
  }
  y <- y1; e <- e1
}
D <- merge(do.call(rbind, rows), MC[, c("step", "node", "h", "Ktrue", "Kend", "Kbr")], by = c("step", "node"))
r <- function(a, b) sqrt(mean((a - b)^2)) / sqrt(mean(a^2)); mb <- function(a, b) mean(b - a) / sqrt(mean(a^2))
for (nm in c("all", "long", "short")) {
  sel <- switch(nm, all = rep(TRUE, nrow(D)), long = D$h > 4 / 365, short = D$h <= 4 / 365)
  cat(sprintf("%-5s n=%d rms err/rms K_true: slope %.3f endpoint %.3f bracket %.3f | bias slope %+.3f endpoint %+.3f\n", nm, sum(sel),
    r(D$Ktrue[sel], D$Kslope[sel]), r(D$Ktrue[sel], D$Kend[sel]), r(D$Ktrue[sel], D$Kbr[sel]), mb(D$Ktrue[sel], D$Kslope[sel]), mb(D$Ktrue[sel], D$Kend[sel])))
}
