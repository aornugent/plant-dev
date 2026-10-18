# Node-to-node roughness of ln nrr inside long spells: |third difference| against |second difference|,
# per case, level 1 at half scale (232-320 nodes), birth dates 6.6-17.7 y and all.
SP <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad"
for (cs in c("dry", "long-wet", "episodic-lma", "dry-flat", "epi-adG208")) {
  f <- readRDS(file.path(SP, "refine/s05", cs, "fit.rds")); sch <- f$schedule
  x <- readRDS(file.path(SP, "refine/s05", cs, "level1.rds"))$stand$nodes; b <- x$birth; y <- log(pmax(x$nrr, 1e-300))
  br <- sch$breaks; pan <- findInterval(b, br + 1e-9)
  res <- lapply(c("6.6-17.7" = 1, all = 2), function(w) { r3 <- c(); r2 <- c()
    for (i in unique(pan)) { k <- which(pan == i); if (length(k) < 8) next; if (w == 1 && (b[k[1]] < 6.6 || b[k[1]] > 17.7)) next
      d2 <- diff(diff(y[k])); d3 <- diff(d2); r2 <- c(r2, abs(d2)); r3 <- c(r3, abs(d3)) }
    c(median(r3) / median(r2), length(r2)) })
  cat(sprintf("%-13s 6.6-17.7 y: roughness %.2f (%d) | all long spells: %.2f (%d)\n", cs, res[[1]][1], res[[1]][2], res[[2]][1], res[[2]][2])) }
