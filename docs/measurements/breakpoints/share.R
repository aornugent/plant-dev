# Per record, on a uniform grid's drop map: the coarsening move from panels that
# straddle a creation-window edge against interior panels, signed and absolute.
source("../adjmap/lib.R")
LAD <- file.path(D, "node_rule/ladder/runs")
src <- c(map_e215 = "u215_episodic", map_e429 = "u429_episodic", map_dry_u215 = "u215_dry", `map_long-wet_u215` = "u215_long-wet")
for (m in commandArgs(TRUE)) {
  x <- run(m); if (is.null(x$soil)) { cat(m, "not done\n"); next }
  cr <- readRDS(file.path(LAD, paste0(src[[m]], ".rds")))$stand$creation; op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]
  b <- nd(x); j <- x$dropped; L <- b$birth[j - 1]; R <- b$birth[j + 1]
  edge <- sapply(seq_along(j), function(i) any(ed > L[i] & ed < R[i]))
  own <- own_drop(b, j) / sum(b$w * b$offspring); fld <- colSums(x$soil + x$light) / x$stand$J; tot <- own + fld
  cat(sprintf("%-18s %3d panels, %3d at an edge | signed: edge %+.5f, interior %+.5f | absolute: edge %.5f, interior %.5f | edge |sum|/sum|.| %.2f, interior %.2f\n",
      m, length(j), sum(edge), sum(tot[edge]), sum(tot[!edge]), sum(abs(tot[edge])), sum(abs(tot[!edge])),
      abs(sum(tot[edge])) / sum(abs(tot[edge])), abs(sum(tot[!edge])) / sum(abs(tot[!edge]))))
}
