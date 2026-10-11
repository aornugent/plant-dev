P2 <- "../placed2/runs"; LAD <- "../../node_rule/ladder/runs"; PL <- "../placement/runs"
runs <- list(pA = file.path(P2, "pA_episodic.rds"), pA2 = file.path(P2, "pA2_episodic.rds"), pA4 = file.path(P2, "pA4_episodic.rds"),
             u108 = file.path(LAD, "u108_episodic.rds"), u215 = file.path(LAD, "u215_episodic.rds"),
             u429 = file.path(LAD, "u429_episodic.rds"), u857 = file.path(PL, "u857_episodic.rds"))
bins <- list(c(0, 2), c(2, 8), c(8, 16), c(16, 40))
cat(sprintf("%-5s %s\n", "", paste(sapply(bins, function(b) sprintf("   [%g,%g): spacing d | max/med |dm| | max/med |dlog nrr|", b[1], b[2])), collapse = "")))
for (k in names(runs)) {
  n <- readRDS(runs[[k]])$stand$nodes; b <- n$birth; m <- n$mortality; f <- n$nrr
  s <- sapply(bins, function(bb) {
    i <- which(b >= bb[1] & b < bb[2]); i <- i[i < length(b)]
    sprintf("   %8.1f | %5.2f %5.2f | %5.2f %5.2f      ", 365 * median(diff(b)[i]), max(abs(diff(m)[i])), median(abs(diff(m)[i])),
            max(abs(diff(log(pmax(f, 1e-12))))[i]), median(abs(diff(log(pmax(f, 1e-12))))[i]))
  })
  cat(sprintf("%-5s %s\n", k, paste(s, collapse = "")))
}
