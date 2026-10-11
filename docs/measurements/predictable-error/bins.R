# Where does the field part leave the square law? Per birth-date bin, time
# band and channel: the drop map's move on u108, u215, u429 (episodic).
source("../adjmap/lib.R")
lv <- c("map_e108", "map_e215", "map_e429")
bb <- c(0, 0.5, 1, 2, 4, 8, 16, 40)
tab <- list()
for (m in lv) {
  x <- run(m); b <- nd(x); J <- x$stand$J; JnP <- sum(b$w * b$offspring)
  bp <- b$birth[x$dropped]
  own <- own_drop(b, x$dropped) / JnP
  bin <- cut(bp, bb, right = FALSE)
  tab[[m]] <- list(own = as.vector(tapply(own, bin, sum)),
                   light = sapply(1:8, function(k) tapply(x$light[k, ] / J, bin, sum)),
                   soil = sapply(1:8, function(k) tapply(x$soil[k, ] / J, bin, sum)),
                   bands = x$bands)
}
f <- function(v) formatC(v, format = "e", digits = 2)
cat("time bands (upper ends):", tab[[1]]$bands, "\n\n")
for (ch in c("own", "light", "soil")) {
  cat("====", ch, "\n")
  for (m in lv) {
    v <- tab[[m]][[ch]]
    if (is.null(dim(v))) cat(sprintf("%-9s", m), f(v), "\n") else {
      cat(m, " (rows: birth bins; cols: time bands)\n"); print(signif(v, 2)) }
  }
  a <- tab[[1]][[ch]]; b <- tab[[2]][[ch]]; c <- tab[[3]][[ch]]
  if (is.null(dim(a))) {
    cat("ratio 108/215:", round(a / b, 2), "\nratio 215/429:", round(b / c, 2), "\n")
  } else {
    cat("row sums  108:", f(rowSums(a)), "\n          215:", f(rowSums(b)), "\n          429:", f(rowSums(c)), "\n")
    cat("ratio 108/215 by birth bin:", round(rowSums(a) / rowSums(b), 2), "\n")
    cat("ratio 215/429 by birth bin:", round(rowSums(b) / rowSums(c), 2), "\n")
    cat("ratio 108/215 by time band:", round(colSums(a) / colSums(b), 2), "\n")
    cat("ratio 215/429 by time band:", round(colSums(b) / colSums(c), 2), "\n")
  }
  cat("\n")
}
cat("totals own+light+soil:", sapply(lv, function(m) sum(tab[[m]]$own) + sum(tab[[m]]$light) + sum(tab[[m]]$soil)), "\n")
