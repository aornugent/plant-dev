source("toy.R")
# Variants of where the slopes are read: the step's start (toy.R), its end before
# the correction, or their mean.
which_B <- Sys.getenv("WHICH_B", "start")
orig <- ck_step
ck_step <- function(t, y, h, e1, th, method = "plain") {
  if (method != "slope_var") return(orig(t, y, h, e1, th, method))
  N <- TOY$N
  k <- matrix(0, length(y), 6); k[, 1] <- e1$dydt; Pst <- matrix(0, N, 6); Pst[, 1] <- e1$P
  for (i in 2:6) {
    yi <- y + h * as.vector(k[, 1:(i - 1), drop = FALSE] %*% A[i, 1:(i - 1)])
    e <- ev(yi, t + cc[i] * h, th); k[, i] <- e$dydt; Pst[, i] <- e$P
  }
  y1 <- y + h * as.vector(k %*% bw); yerr <- h * as.vector(k %*% ec)
  e_end <- ev(y1, t + h, th)
  Bs <- slopes_at_zero(e1$state); Be <- slopes_at_zero(e_end$state)
  B <- switch(which_B, start = Bs, end = Be, mean = (Bs + Be) / 2)
  Kn <- vapply(seq_len(N), function(j) kink_K_slope(c(Pst[j, ], e_end$P[j]), Pst[j, ]), 0)
  if (any(Kn != 0)) {
    idx <- 1:(NC * N); y1[idx] <- y1[idx] + h * as.vector(B %*% diag(Kn, N)); e_end <- ev(y1, t + h, th)
  }
  list(y = y1, yerr = yerr, e_end = e_end)
}
