a <- readRDS(commandArgs(TRUE)[1]); b <- readRDS(commandArgs(TRUE)[2])
for (L in names(a)) {
  ga <- a[[L]]$gradient; gb <- b[[L]]$gradient
  stopifnot(identical(dimnames(ga), dimnames(gb)))
  rel <- abs(ga - gb) / pmax(abs(ga), 1e-300)
  cat(sprintf("L=%s steps %d/%d  values identical=%s  entries=%d finite=%d/%d  bit-identical=%d  dropped=%d  max rel=%.2e  median rel(moved)=%.2e\n",
      L, a[[L]]$steps, b[[L]]$steps, identical(a[[L]]$value, b[[L]]$value), length(ga),
      sum(is.finite(ga)), sum(is.finite(gb)), sum(ga == gb, na.rm = TRUE),
      sum(ga != 0 & gb == 0, na.rm = TRUE), max(rel, na.rm = TRUE),
      median(rel[ga != gb], na.rm = TRUE)))
  w <- which(rel == max(rel, na.rm = TRUE), arr.ind = TRUE)[1, ]
  cat(sprintf("   worst: %s / %s  %.10g vs %.10g\n", rownames(ga)[w[1]], colnames(ga)[w[2]], ga[w[1], w[2]], gb[w[1], w[2]]))
}
