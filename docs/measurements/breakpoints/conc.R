# How concentrated the edge panels' moves are, and when they are born.
source("../adjmap/lib.R"); LAD <- file.path(D, "node_rule/ladder/runs")
src <- c(map_e215 = "u215_episodic", map_dry_u215 = "u215_dry", `map_long-wet_u215` = "u215_long-wet")
for (m in names(src)) {
  x <- run(m); cr <- readRDS(file.path(LAD, paste0(src[[m]], ".rds")))$stand$creation
  op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]
  b <- nd(x); j <- x$dropped; L <- b$birth[j - 1]; R <- b$birth[j + 1]
  edge <- sapply(seq_along(j), function(i) any(ed > L[i] & ed < R[i]))
  tot <- own_drop(b, j) / sum(b$w * b$offspring) + colSums(x$soil + x$light) / x$stand$J
  a <- sort(abs(tot[edge]), decreasing = TRUE); cs <- cumsum(a) / sum(a)
  bb <- b$birth[j][edge]; big <- abs(tot[edge]) > 0.025 / 10
  cat(sprintf("%-18s %d edge panels: 50%% of |edge| in %d, 90%% in %d; panels over eps/10: %d (births %s)\n", m, length(a),
      which(cs >= 0.5)[1], which(cs >= 0.9)[1], sum(big), paste(round(sort(bb[big]), 1), collapse = " ")))
}
