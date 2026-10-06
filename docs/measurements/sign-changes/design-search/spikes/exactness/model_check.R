# On each crossing node-step: does h * B * K_true (the positive part's quadrature
# error along the true path of P) explain plain's local error, and how well do the
# endpoint quartic and the bracket estimate K_true?
source("toy.R")
setup()
th0 <- c(2, 0.35, 0.05)
mesh <- run_adaptive(th0, 1e-4, "plain")$times
fine <- function(t, y, h, th, m = 512) {
  hs <- h / m; Ps <- matrix(0, TOY$N, m + 1); Bs <- list()
  e <- rates(y, t, th); Ps[, 1] <- e$P; Bs[[1]] <- slopes_at_zero(e$state)
  for (q in 0:(m - 1)) {
    tq <- t + q * hs
    a1 <- rates(y, tq, th)$dydt; a2 <- rates(y + hs / 2 * a1, tq + hs / 2, th)$dydt
    a3 <- rates(y + hs / 2 * a2, tq + hs / 2, th)$dydt; a4 <- rates(y + hs * a3, tq + hs, th)$dydt
    y <- y + hs / 6 * (a1 + 2 * a2 + 2 * a3 + a4)
    e <- rates(y, tq + hs, th); Ps[, q + 2] <- e$P; Bs[[q + 2]] <- slopes_at_zero(e$state)
  }
  list(y = y, P = Ps, B = Bs)
}
N <- TOY$N; y <- TOY$y0; e <- rates(y, 0, th0); rows <- list()
for (i in 2:length(mesh)) {
  t <- mesh[i - 1]; h <- mesh[i] - t
  # the plain step, keeping its stage P values
  k <- matrix(0, length(y), 6); k[, 1] <- e$dydt; Pst <- matrix(0, N, 6); Pst[, 1] <- e$P
  for (s in 2:6) {
    yi <- y + h * as.vector(k[, 1:(s - 1), drop = FALSE] %*% A[s, 1:(s - 1)])
    es <- rates(yi, t + cc[s] * h, th0); k[, s] <- es$dydt; Pst[, s] <- es$P
  }
  y1 <- y + h * as.vector(k %*% bw); e1 <- rates(y1, t + h, th0)
  ch <- which(sign(e1$P) != sign(e$P))
  if (length(ch)) {
    f <- fine(t, y, h, th0)
    B0 <- slopes_at_zero(e$state)
    for (j in ch) {
      gP <- gfun(f$P[j, ]); m <- length(gP) - 1
      Itrue <- (sum(gP) - (gP[1] + gP[m + 1]) / 2) / m        # trapezoid on 512 pieces
      Ktrue <- Itrue - sum(bw * gfun(Pst[j, ]))
      Kend <- kink_K_end(c(Pst[j, c(1, 3, 4, 6)], e1$P[j]), Pst[j, ])
      # the bracket's K, as h^2 * Pdot * Ksharp / h
      cs <- c(cc[-5], 1); o <- order(cs); csx <- cs[o]; p <- c(Pst[j, -5], e1$P[j])[o]
      b <- which(sign(p) != sign(p[1]))[1]
      u <- csx[b - 1] + (csx[b] - csx[b - 1]) * p[b - 1] / (p[b - 1] - p[b])
      Pdot <- abs(p[b] - p[b - 1]) / ((csx[b] - csx[b - 1]) * h)
      Kbr <- -h * Pdot * Ksharp(u)
      idx <- (j - 1) * NC + 1:NC
      eplain <- y1[idx] - f$y[idx]
      rows[[length(rows) + 1]] <- data.frame(step = i, node = j, h = h, Ktrue = Ktrue, Kend = Kend, Kbr = Kbr,
        eS = eplain[2], predS = -h * B0[2, j] * Ktrue, eH = eplain[1], predH = -h * B0[1, j] * Ktrue,
        BSvar = diff(range(sapply(f$B, function(B) B[2, j]))), BS0 = B0[2, j])
    }
  }
  y <- y1; e <- e1
}
D <- do.call(rbind, rows); saveRDS(D, "model_check.rds")
r <- function(a, b) sqrt(mean((a - b)^2)) / sqrt(mean(a^2))
cat(sprintf("crossing node-steps %d\n", nrow(D)))
cat(sprintf("plain's local error explained by -h B0 K_true: residual rms / rms  S %.3f  H %.3f\n", r(D$eS, D$predS), r(D$eH, D$predH)))
cat(sprintf("K estimates against K_true: rms error / rms K_true  endpoint %.3f  bracket %.3f\n", r(D$Ktrue, D$Kend), r(D$Ktrue, D$Kbr)))
long <- D$h > 4 / 365
cat(sprintf("steps longer than 4 days (%d): explained S %.3f H %.3f; endpoint %.3f bracket %.3f\n", sum(long),
            r(D$eS[long], D$predS[long]), r(D$eH[long], D$predH[long]), r(D$Ktrue[long], D$Kend[long]), r(D$Ktrue[long], D$Kbr[long])))
cat(sprintf("short steps (%d): explained S %.3f H %.3f; endpoint %.3f bracket %.3f\n", sum(!long),
            r(D$eS[!long], D$predS[!long]), r(D$eH[!long], D$predH[!long]), r(D$Ktrue[!long], D$Kend[!long]), r(D$Ktrue[!long], D$Kbr[!long])))
cat(sprintf("B_S's range over a step relative to |B_S| at the start: median %.3f, 90%% %.3f\n",
            median(D$BSvar / abs(D$BS0)), quantile(D$BSvar / abs(D$BS0), 0.9)))
