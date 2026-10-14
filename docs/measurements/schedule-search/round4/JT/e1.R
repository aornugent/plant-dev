# e1.R: A's and B's cumulative TF24_cost_scale adjoint (from T back), in eps of the
# elasticity, at the step starts the two runs share, and its A - B change by window.
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
eps <- 0.0196115
ld <- function(n) { x <- readRDS(file.path(O, paste0(n, ".rds"))); tr <- readRDS(file.path(O, paste0(n, "_trace.rds")))
  ic <- which(names(x$gradient) == "1.TF24_cost_scale"); s <- x$theta[ic] / x$J / eps
  P <- tr$params; list(x = x, t = P[, 2], h = P[, 3], cum = P[, 3 + ic] * s, k = P[, 1], s = s) }
A <- ld(Sys.getenv("RA", "JT1_A")); B <- ld(Sys.getenv("RB", "JT1_B"))
cat(sprintf("elasticity A %.5f B %.5f, A-B %.4f eps\n", A$x$elasticity[["1.TF24_cost_scale"]], B$x$elasticity[["1.TF24_cost_scale"]],
  (A$x$elasticity[["1.TF24_cost_scale"]] - B$x$elasticity[["1.TF24_cost_scale"]]) / eps))
# The value at a time: the cumulative after the last step starting at or after it (rows run T back).
at <- function(R, t) { i <- which(R$t >= t - 1e-12); R$cum[i[length(i)]] }
sh <- sort(unique(A$t[vapply(A$t, function(t) any(abs(B$t - t) < 1e-9), TRUE)]))
D <- vapply(sh, function(t) at(A, t) - at(B, t), 0)
brk <- c(0, 1, 3.5, 5, 6.7, 8.25, 9.15, 9.678, 9.753, 10.04, 17, 25, 40)
for (j in seq_len(length(brk) - 1)) { i0 <- which(sh >= brk[j])[1]; i1 <- tail(which(sh <= brk[j + 1]), 1)
  if (is.na(i0) || length(i1) == 0) next
  cat(sprintf("%6.3f-%6.3f: D from %+.4f to %+.4f, change across %+.4f eps\n", sh[i0], sh[i1], D[i1], D[i0], D[i0] - D[i1])) }
w <- sh > 9.6 & sh < 9.8
print(data.frame(t = sh[w], D = D[w]), digits = 5)
saveRDS(list(t = sh, D = D), file.path(O, "e1_D.rds"))
