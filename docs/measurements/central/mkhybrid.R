# H = G plus the midpoints of the intervals no central drop of G covers; its coarsening
# drops those central nodes and those midpoints, so every dropped node is central.
#   Rscript mkhybrid.R G.rds FIRST_PASS.rds TAG
a <- commandArgs(TRUE); g <- readRDS(a[1]); cr <- readRDS(a[2])$stand$creation; tag <- a[3]
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]
edge <- round(g, 9) %in% round(ed, 9); drop <- logical(length(g)); i <- 2
while (i < length(g)) { l <- (g[i] - g[i - 1]) / (g[i + 1] - g[i - 1])
  if (!edge[i] && !drop[i - 1] && l >= 0.35 && l <= 0.65) { drop[i] <- TRUE; i <- i + 2 } else i <- i + 1 }
covered <- logical(length(g) - 1); covered[c(which(drop) - 1, which(drop))] <- TRUE
mid <- (head(g, -1) + diff(g) / 2)[!covered]
h <- sort(c(g, mid)); coarse <- sort(g[!drop])
H <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/hier"
saveRDS(h, file.path(H, paste0("hyb_", tag, ".rds"))); saveRDS(coarse, file.path(H, paste0("hybC_", tag, ".rds")))
cat(sprintf("%s: G %d nodes, %d central drops, %d midpoints added -> H %d nodes (%.2f x G), coarse %d\n", tag, length(g), sum(drop), length(mid), length(h), length(h) / length(g), length(coarse)))
