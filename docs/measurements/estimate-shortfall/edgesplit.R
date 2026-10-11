# The map's coarsening move split by whether the dropped node is a first-pass edge.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
edges <- function(cr) { op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); data.frame(b = cr$end[e][-length(e)], opening = !op[e][-length(e)]) }
for (cs in list(c("u108e_episodic_p1", "th0", "episodic"), c("u108e_episodic_p3", "th0", "episodic"), c("s16_dry_p3", "th0", "dry"))) {
  x <- run(paste0("ref_", cs[1])); ed <- edges(readRDS(file.path(D, sprintf("schedtest/placed2/runs/m_%s_f_%s.rds", cs[2], cs[3])))$stand$creation)
  b <- nd(x); j <- x$dropped; own <- own_drop(b, j) / sum(b$w * b$offspring); fld <- colSums(x$light + x$soil) / x$stand$J
  tb <- x$node_times[j]; k <- match(round(tb, 9), round(ed$b, 9)); cls <- ifelse(is.na(k), "interior", ifelse(ed$opening[k], "opening", "closing"))
  cat(sprintf("\n%s: dropped %d (openings %d, closings %d)\n", cs[1], length(j), sum(cls == "opening"), sum(cls == "closing")))
  print(round(rbind(own = tapply(own, cls, sum), field = tapply(fld, cls, sum), total = tapply(own + fld, cls, sum), abs = tapply(abs(own + fld), cls, sum)) / 0.025, 3))
}
