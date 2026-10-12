# pass.R CASE K [S]: rank every current panel of G<K> by its move of ln J, from the
# latest map run that dropped its middle node (loc_G0..G<K>_CASE); bisect both
# intervals of the fewest panels carrying share S of the summed |move|; write G<K+1>,
# and C<K+1> = G<K>, so G<K+1>'s map drops exactly the new midpoints.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
a <- commandArgs(TRUE); case <- a[1]; K <- as.integer(a[2]); s <- if (length(a) > 2) as.numeric(a[3]) else 0.75
L <- file.path(dirname(A), "loc"); GK <- run(sprintf("loc_G%d_%s", K, case))$node_times
panels <- do.call(rbind, lapply(0:K, function(r) { x <- run(sprintf("loc_G%d_%s", r, case)); G <- x$node_times; j <- x$dropped; b <- nd(x)
  m <- own_drop(b, j) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J
  data.frame(pass = r, lo = G[j - 1], mid = G[j], hi = G[j + 1], m = m) }))
inside <- function(lo, mid, hi) sum(GK > lo + 1e-10 & GK < hi - 1e-10 & abs(GK - mid) > 1e-10)
panels <- panels[mapply(inside, panels$lo, panels$mid, panels$hi) == 0, ]
o <- order(-abs(panels$m)); cum <- cumsum(abs(panels$m[o])) / sum(abs(panels$m))
pick <- o[seq_len(which(cum >= s)[1])]; P <- panels[pick, ]
mids <- c((P$lo + P$mid) / 2, (P$mid + P$hi) / 2)
G1 <- sort(unique(round(c(GK, mids), 10)))
saveRDS(G1, file.path(L, sprintf("G%d_%s.rds", K + 1, case))); saveRDS(GK, file.path(L, sprintf("C%d_%s.rds", K + 1, case)))
saveRDS(list(panels = panels, pick = pick, predicted = -sum(P$m) / 4), file.path(L, sprintf("pass%d_%s.rds", K, case)))
band <- cut(panels$mid, c(0, 3.6, 10, 20, 25, 40))
cat(sprintf("%s pass %d: %d current panels, sum|m| %.3f eps, sum m %+.3f eps; picked %d for share %.2f; G%d %d nodes (+%d)\n",
  case, K, nrow(panels), sum(abs(panels$m)) / 0.025, sum(panels$m) / 0.025, length(pick), s, K + 1, length(G1), length(mids)))
cat("sum|m| by birth band (eps):", paste(sprintf("%s %.3f", levels(band), tapply(abs(panels$m), band, sum) / 0.025), collapse = ", "), "\n")
cat("picked by band:", paste(sprintf("%s %d", levels(band), tabulate(band[pick], nlevels(band))), collapse = ", "), "\n")
cat(sprintf("predicted ln J move G%d -> G%d: %+.4f eps\n", K, K + 1, -sum(P$m) / 4 / 0.025))
