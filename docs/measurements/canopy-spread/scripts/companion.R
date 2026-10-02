# The invader's lma elasticity on a ladder of invader_nodes.R runs: each rung's
# error against a reference, and its companion's estimate (a third of the move
# from the coarser rung) over that error. The reference is the graded ladder's
# extrapolation from G2 and G3 (the sweep's -27.0481, -27.0415), shifted by the
# central difference's offset from the sweep at G2 (-27.0520 vs -27.0481).
# Usage: Rscript companion.R a.rds b.rds c.rds
f <- commandArgs(TRUE); x <- lapply(f, readRDS)
el <- function(x) { J <- vapply(x$invader, `[[`, 0, "J"); (J[["plus"]] - J[["minus"]]) / (2 * x$u * x$stand$J) }
e <- vapply(x, el, 0)
ref <- -27.0415 + (-27.0415 + 27.0481) / 3 + (-27.0520 + 27.0481)
own <- e[3] + (e[3] - e[2]) / 3
cat(sprintf("reference %.4f (graded, central-difference terms); this ladder's own extrapolation %.4f\n", ref, own))
for (i in seq_along(e)) {
  err <- e[i] - ref
  line <- sprintf("%-22s %.4f  error %+.4f (%.2f eps)", basename(f[i]), e[i], err, abs(err) / 0.20)
  if (i > 1) { est <- abs(e[i - 1] - e[i]) / 3; line <- paste0(line, sprintf("  companion estimate %.4f, over error %.2f", est, est / abs(err))) }
  cat(line, "\n")
}
