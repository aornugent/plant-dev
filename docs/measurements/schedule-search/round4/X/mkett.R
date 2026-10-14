# mkett.R CASE F: the rule-A window weight with the tolerance cut by F within 15 days of
# every closing edge before b = 25 (the pilot's edges), on a 1-day grid.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
a <- commandArgs(TRUE); cs <- a[1]; f <- as.numeric(a[2]); out <- a[3]
w <- readRDS(sprintf("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/window/rule_A/weight_%s.rds", sub("-p50|-flat", "", cs)))
et <- edge_table(cs); cl <- et$b[!et$opening]; t <- sort(unique(c(w$t, seq(0, 25, by = 1 / 365))))
base <- w$weight[findInterval(t, w$t)]; near <- vapply(t, function(x) any(abs(cl - x) <= 15 / 365), TRUE)
saveRDS(data.frame(t = t, weight = base * ifelse(near, f, 1)), out)
cat(sprintf("%s: %d closing edges, %.0f%% of 0-25 inside a window\n", cs, length(cl), 100 * mean(near[t < 25])))
