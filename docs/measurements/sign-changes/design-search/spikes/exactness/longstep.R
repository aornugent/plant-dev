source("toy.R")
setup()
th0 <- c(2, 0.35, 0.05)
D <- readRDS("model_check.rds")
long <- D[D$h > 4 / 365, ]
cat(sprintf("long steps: mean(Kend - Ktrue) / rms Ktrue = %.3f ; mean(Kbr - Ktrue)/rms = %.3f\n",
            mean(long$Kend - long$Ktrue) / sqrt(mean(long$Ktrue^2)), mean(long$Kbr - long$Ktrue) / sqrt(mean(long$Ktrue^2))))
short <- D[D$h <= 4 / 365, ]
cat(sprintf("short steps: mean(Kend - Ktrue) / rms Ktrue = %.3f ; mean(Kbr - Ktrue)/rms = %.3f\n",
            mean(short$Kend - short$Ktrue) / sqrt(mean(short$Ktrue^2)), mean(short$Kbr - short$Ktrue) / sqrt(mean(short$Ktrue^2))))
# One outlier: stage P values against P along the fine path at the stage times.
mesh <- run_adaptive(th0, 1e-4, "plain")$times
o <- long[order(-abs(long$Kend - long$Ktrue)), ][1:3, ]
y <- TOY$y0; e <- rates(y, 0, th0)
for (i in 2:max(o$step)) {
  t <- mesh[i - 1]; h <- mesh[i] - t
  if (i %in% o$step) {
    k <- matrix(0, length(y), 6); k[, 1] <- e$dydt; Pst <- matrix(0, TOY$N, 6); Pst[, 1] <- e$P; W <- numeric(6); W[1] <- y[length(y)]
    for (s in 2:6) { yi <- y + h * as.vector(k[, 1:(s - 1), drop = FALSE] %*% A[s, 1:(s - 1)]); es <- rates(yi, t + cc[s] * h, th0); k[, s] <- es$dydt; Pst[, s] <- es$P; W[s] <- yi[length(yi)] }
    # fine path at the stage times
    m <- 1024; hs <- h / m; yy <- y; Pf <- matrix(0, TOY$N, m + 1); Wf <- numeric(m + 1); Pf[, 1] <- e$P; Wf[1] <- y[length(y)]
    for (q in 0:(m - 1)) { tq <- t + q * hs
      a1 <- rates(yy, tq, th0)$dydt; a2 <- rates(yy + hs/2*a1, tq + hs/2, th0)$dydt; a3 <- rates(yy + hs/2*a2, tq + hs/2, th0)$dydt; a4 <- rates(yy + hs*a3, tq + hs, th0)$dydt
      yy <- yy + hs/6*(a1 + 2*a2 + 2*a3 + a4); Pf[, q + 2] <- rates(yy, tq + hs, th0)$P; Wf[q + 2] <- yy[length(yy)] }
    y1 <- y + h * as.vector(k %*% bw); e1 <- rates(y1, t + h, th0)
    for (j in o$node[o$step == i]) {
      at <- round(cc * m) + 1
      cat(sprintf("step %d node %d h %.2f d: stage P   %s | end %.4f\n", i, j, h * 365, paste(sprintf("%.4f", Pst[j, ]), collapse = " "), e1$P[j]))
      cat(sprintf("                         true P   %s | end %.4f\n", paste(sprintf("%.4f", Pf[j, at]), collapse = " "), Pf[j, m + 1]))
      cat(sprintf("                         stage w  %s | true w %s\n", paste(sprintf("%.4f", W), collapse = " "), paste(sprintf("%.4f", Wf[at]), collapse = " ")))
    }
  }
  s <- ck_step(t, y, h, e, th0, "plain"); y <- s$y; e <- s$e_end
}
