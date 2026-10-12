# pass.R CASE K [S]: from map run loc_G<K>_CASE, rank each dropped node's panel by its
# move of ln J, bisect both intervals of the fewest panels carrying share S of the
# summed |move|, and write G<K+1> and C<K+1> (C drops the new midpoints).
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
a <- commandArgs(TRUE); case <- a[1]; k <- as.integer(a[2]); s <- if (length(a) > 2) as.numeric(a[3]) else 0.75
L <- file.path(dirname(A), "loc"); x <- run(sprintf("loc_G%d_%s", k, case)); G <- x$node_times
b <- nd(x); move <- own_drop(b, x$dropped) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J
j <- x$dropped; o <- order(-abs(move)); cum <- cumsum(abs(move[o])) / sum(abs(move))
pick <- o[seq_len(which(cum >= s)[1])]
mids <- sort(unique(c((G[j[pick] - 1] + G[j[pick]]) / 2, (G[j[pick]] + G[j[pick] + 1]) / 2)))
G1 <- sort(unique(round(c(G, mids), 10))); C1 <- G
saveRDS(G1, file.path(L, sprintf("G%d_%s.rds", k + 1, case))); saveRDS(C1, file.path(L, sprintf("C%d_%s.rds", k + 1, case)))
saveRDS(list(move = move, birth = G[j], pick = pick, predicted = sum(move[pick]) / 4), file.path(L, sprintf("pass%d_%s.rds", k, case)))
band <- cut(G[j], c(0, 3.6, 10, 20, 25, 40))
cat(sprintf("%s pass %d: %d panels, sum|m| %.3f eps, sum m %+.3f eps; picked %d (share %.2f); G%d %d nodes (+%d)\n",
  case, k, length(j), sum(abs(move)) / 0.025, sum(move) / 0.025, length(pick), s, k + 1, length(G1), length(mids)))
cat("sum|m| by birth band (eps):", paste(sprintf("%s %.3f", levels(band), tapply(abs(move), band, sum) / 0.025), collapse = ", "), "\n")
cat("picked by band:", paste(sprintf("%s %d", levels(band), tabulate(band[pick], nlevels(band))), collapse = ", "), "\n")
cat(sprintf("predicted ln J move G%d -> G%d: %+.4f eps\n", k, k + 1, sum(move[pick]) / 4 / 0.025))
