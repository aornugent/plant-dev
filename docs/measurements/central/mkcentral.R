# A coarsening of G that drops only central nodes: greedily, left to right, a node that
# is not a first-pass edge, whose neighbours are both kept, at l in [0.35, 0.65] of its
# panel.  Rscript mkcentral.R G.rds FIRST_PASS.rds OUT.rds
a <- commandArgs(TRUE); g <- readRDS(a[1]); cr <- readRDS(a[2])$stand$creation
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]
edge <- round(g, 9) %in% round(ed, 9); drop <- logical(length(g)); i <- 2
while (i < length(g)) { l <- (g[i] - g[i - 1]) / (g[i + 1] - g[i - 1])
  if (!edge[i] && !drop[i - 1] && l >= 0.35 && l <= 0.65) { drop[i] <- TRUE; i <- i + 2 } else i <- i + 1 }
saveRDS(g[!drop], a[3])
cover <- sum(sapply(which(drop), function(i) g[i + 1] - g[i - 1])) / (max(g) - min(g))
cat(sprintf("%d nodes, %d dropped, panels cover %.0f%% of the birth dates\n", length(g), sum(drop), 100 * cover))
