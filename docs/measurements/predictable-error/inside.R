# Inside the largest edge regions: node births, interval counts, fates, and where
# establishment opens or shuts, on pA2L and pA4L.
source("../adjmap/lib.R")
P2 <- file.path(D, "schedtest/placed2/runs")
x4 <- readRDS(file.path(P2, "pA4L_episodic.rds")); cr <- x4$stand$creation
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths)
ed <- data.frame(t = cr$end[e][-length(e)], kind = ifelse(r$values[-length(r$values)], "shuts", "opens"))
show <- function(lo, hi) {
  cat(sprintf("\n--- b in [%.3f, %.3f]; edges: %s\n", lo, hi, paste(sprintf("%s %.4f", ed$kind, ed$t)[ed$t > lo & ed$t < hi], collapse = ", ")))
  for (k in c("pA2L", "pA4L")) {
    n <- readRDS(file.path(P2, paste0(k, "_episodic.rds")))$stand$nodes; m <- length(n$birth)
    i <- which(n$birth >= lo & n$birth <= hi)
    cat(k, "\n"); print(data.frame(b = round(n$birth[i], 4), count = signif(n$establishment[i], 3),
                                    nrr = signif(n$nrr[i], 4), mort = round(n$mortality[i], 3)), row.names = FALSE)
  }
}
show(12.45, 13.10); show(14.40, 14.80)
