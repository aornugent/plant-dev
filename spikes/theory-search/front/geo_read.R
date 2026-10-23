for (k in c(4, 8, 12)) {
  r <- readRDS(sprintf("/tmp/front/geo_%d.rds", k))
  cat("GEOM", k, " F", r$F, "\n")
  t <- r$node_times[[1]]; b <- r$by_node[[1]]; i <- which(t < 1.2)
  print(signif(rbind(t = t[i], W = b[i]), 3))
}
