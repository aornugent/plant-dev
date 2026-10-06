source("toy.R"); source("variants.R")
setup()
th0 <- c(2, 0.35, 0.05)
mesh <- run_adaptive(th0, 1e-4, "plain")$times
fine_step <- function(t, y, h, th, m = 256) {
  hs <- h / m
  for (q in 0:(m - 1)) {
    tq <- t + q * hs
    a1 <- rates(y, tq, th)$dydt; a2 <- rates(y + hs / 2 * a1, tq + hs / 2, th)$dydt
    a3 <- rates(y + hs / 2 * a2, tq + hs / 2, th)$dydt; a4 <- rates(y + hs * a3, tq + hs, th)$dydt
    y <- y + hs / 6 * (a1 + 2 * a2 + 2 * a3 + a4)
  }
  y
}
vars <- c("plain", "q5", "c4", "q2")
N <- TOY$N; y <- TOY$y0; e <- rates(y, 0, th0); out <- list()
for (i in 2:length(mesh)) {
  t <- mesh[i - 1]; h <- mesh[i] - t
  s <- ck_step(t, y, h, e, th0, "plain")
  ch <- which(sign(s$e_end$P) != sign(e$P))
  if (length(ch)) {
    d <- 1e-6; up <- th0; up[1] <- th0[1] * exp(d); dn <- th0; dn[1] <- th0[1] * exp(-d)
    ref <- fine_step(t, y, h, th0); refu <- fine_step(t, y, h, up); refd <- fine_step(t, y, h, dn)
    eu <- rates(y, t, up); ed <- rates(y, t, dn)
    for (v in vars) {
      m <- if (v == "plain") "plain" else { set_variant(v); "smooth" }
      ym <- ck_step(t, y, h, e, th0, m)$y; yu <- ck_step(t, y, h, eu, up, m)$y; yd <- ck_step(t, y, h, ed, dn, m)$y
      err <- ym - ref; derr <- ((yu - refu) - (yd - refd)) / (2 * d)
      for (j in ch) {
        rows <- (j - 1) * NC + 1:NC
        out[[length(out) + 1]] <- data.frame(step = i, node = j, v = v, eH = err[rows[1]], eS = err[rows[2]],
          eO = err[rows[5]], dH = derr[rows[1]], dS = derr[rows[2]], dO = derr[rows[5]])
      }
    }
  }
  y <- s$y; e <- s$e_end
}
D <- do.call(rbind, out); saveRDS(D, "local_var.rds")
for (q in c("eH", "eS", "eO", "dH", "dS", "dO")) {
  P <- D[D$v == "plain", q]; cat(sprintf("%s rms plain %.3g:", q, sqrt(mean(P^2))))
  for (v in vars[-1]) { M <- D[D$v == v, q]; cat(sprintf("  %s %.3f", v, sqrt(mean(M^2)) / sqrt(mean(P^2)))) }
  cat("\n")
}
