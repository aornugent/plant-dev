# mk_rule_r.R: the guarded rule's windows: L's pairs whose two widths are within a factor 2
# of each other (rule_r.txt), any region.
SU <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
LAY <- readRDS(file.path(SU, "sched", "layout.rds")); CS <- names(LAY$info)
w <- vapply(CS, function(cs) { pr <- LAY$info[[cs]]$pairs; r <- (pr$b2 - pr$b1) / (pr$b1 - pr$b0); x <- pr[r >= 0.5 & r <= 2, ]
  cat(sprintf("%-12s pairs kept %d of %d (F %d K %d P %d I %d Z %d)\n", cs, nrow(x), nrow(pr), sum(x$region == "F"), sum(x$region == "K"), sum(x$region == "P"), sum(x$region == "I"), sum(x$region == "Z")))
  paste(sprintf("%.10f:%.10f", x$b0, x$b2), collapse = ",") }, "")
writeLines(sprintf("%s %s", CS, w), file.path(SU, "sched", "rule_r.txt"))
