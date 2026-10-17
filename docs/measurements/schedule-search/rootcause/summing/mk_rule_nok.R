# mk_rule_nok.R: the windows of every L pair except the K pairs (a gap interval paired with
# the closing spell's last interval, i.e. the closing inset node as the pair's middle node).
SU <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
LAY <- readRDS(file.path(SU, "sched", "layout.rds")); CS <- names(LAY$info)
w <- vapply(CS, function(cs) { pr <- LAY$info[[cs]]$pairs; x <- pr[pr$region != "K", ]; paste(sprintf("%.10f:%.10f", x$b0, x$b2), collapse = ",") }, "")
writeLines(sprintf("%s %s", CS, w), file.path(SU, "sched", "rule_noK.txt"))
