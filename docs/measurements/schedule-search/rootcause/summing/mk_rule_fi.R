# mk_rule_fi.R: the windows of L's founders' and interior pairs only (F, I): no pair holding
# a gap interval, no late pair.
SU <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
LAY <- readRDS(file.path(SU, "sched", "layout.rds")); CS <- names(LAY$info)
w <- vapply(CS, function(cs) { pr <- LAY$info[[cs]]$pairs; x <- pr[pr$region %in% c("F", "I"), ]; paste(sprintf("%.10f:%.10f", x$b0, x$b2), collapse = ",") }, "")
writeLines(sprintf("%s %s", CS, w), file.path(SU, "sched", "rule_FI.txt"))
