for (f in Sys.glob("exp2_*_1e-04.rds")) {
  S <- readRDS(f); u <- S$u; e <- S$e1; L <- S$lnJ
  d2e <- diff(e, differences = 2); d3L <- diff(L, differences = 3)
  fitE <- lm(e ~ poly(u, 3)); fitL <- lm(L ~ poly(u, 4))
  # the chord against the second difference of lnJ at r = 1e-2, 5e-3, 2.5e-3
  i0 <- which.min(abs(u)); dr <- c(40, 20, 10)
  ch <- sapply(dr, function(k) (e[i0 + k] - e[i0 - k]) / (u[i0 + k] - u[i0 - k]))
  sd2 <- sapply(dr, function(k) (L[i0 + k] - 2 * L[i0] + L[i0 - k]) / (u[i0 + k] - u[i0])^2)
  cat(sprintf("%-10s rms second diff of e1 %.3g | e1 resid from cubic sd %.3g | lnJ resid from quartic sd %.3g max |third diff| %.3g\n",
              S$method, sqrt(mean(d2e^2)), sd(resid(fitE)), sd(resid(fitL)), max(abs(d3L))))
  cat(sprintf("           chords r=1e-2,5e-3,2.5e-3: %s | second differences: %s\n",
              paste(sprintf("%.4f", ch), collapse = " "), paste(sprintf("%.4f", sd2), collapse = " ")))
}
