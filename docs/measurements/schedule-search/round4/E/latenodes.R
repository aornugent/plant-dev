# Rows carried by nodes born late, per committed run: what the late introductions cost.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/E/common.R")
res <- readRDS(file.path(EO, "steps.rds"))
for (cs in CASES10) { x <- readRDS(a09_file(cs, "c")); nt <- sort(x$node_times); d <- res[[paste(cs, "c")]]
  tot <- sum(d$alive)
  r <- sapply(c(20, 25, 30, 33), function(b) sum(vapply(d$start, function(s) sum(nt > b & nt <= s), 0)))
  cat(sprintf("%-13s nodes %3d (after 20: %2d, 25: %2d, 30: %2d) | rows of nodes born after 20/25/30/33: %4.1f%% %4.1f%% %4.1f%% %4.1f%%\n",
    cs, length(nt), sum(nt > 20), sum(nt > 25), sum(nt > 30), 100 * r[1] / tot, 100 * r[2] / tot, 100 * r[3] / tot, 100 * r[4] / tot)) }
