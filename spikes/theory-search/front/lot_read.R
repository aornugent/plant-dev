for (sh in c("-0.693147", "0", "0.693147")) {
  r <- readRDS(sprintf("/tmp/front/lot_%s.rds", sh))
  b <- exp(3.595 + as.numeric(sh))
  t <- r$node_times[[1]]; W <- r$by_node[[1]]
  i <- which(t < 0.75)
  # spike mass by trapezoid over [0, 0.75] against the rest
  tt <- t; ww <- c(diff(tt), 0) / 2 + c(0, diff(tt)) / 2
  inner <- sum((W * ww)[t < 0.75]); outer <- sum((W * ww)[t >= 0.75])
  cat(sprintf("lnb shift %s  F %.4f  W(0) %.1f  inner mass %.3f  outer %.3f  b*inner %.2f\n", sh, r$F, W[1], inner, outer, b * inner))
  half <- approx(W[i] / W[1], t[i], xout = 0.5, ties = "ordered")$y
  cat(sprintf("   half-width s_1/2 = %.4f yr ; b * s_1/2 = %.3f\n", half, b * half))
}
