# Itinerary changes not at a creation edge: neighbour pairs (both with count)
# whose sign-change counts differ and no edge lies between them, ranked by the
# jump in survival to the run's end and in log net reproduction.
Q <- "../placed2/runs"
for (nm in commandArgs(TRUE)) {
  x <- readRDS(file.path(Q, paste0(nm, ".rds")))$stand; n <- x$nodes; b <- n$birth; k <- length(b); s <- x$splits
  cr <- x$creation; op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]
  i <- seq_len(k - 1); edge <- sapply(i, function(j) any(ed > b[j] & ed < b[j + 1]))
  cnt <- n$establishment[1:k]; ok <- cnt[i] > 0 | cnt[i + 1] > 0
  ch <- s[i] != s[i + 1] & !edge & ok
  dS <- abs(diff(exp(-n$mortality))); dL <- abs(diff(log(pmax(n$nrr, 1e-12))))
  o <- which(ch)[order(-dS[ch])][1:min(6, sum(ch))]
  cat(sprintf("%-26s %d pairs, %d itinerary changes off edges (%.0f%%); largest by survival jump:\n", nm, k - 1, sum(ch), 100 * mean(ch)))
  if (length(o)) print(data.frame(day = round(365 * b[o], 2), to = round(365 * b[o + 1], 2), counts = paste(s[o], s[o + 1]),
                   dSurv = signif(dS[o], 2), dlogF = signif(dL[o], 2)), row.names = FALSE)
}
