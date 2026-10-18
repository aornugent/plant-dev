# The loop's three runs on one case, for sampling under gperftools (run by prof.sh).
#   CASE=<case> PLANT_LIB=<lib> exec/R -f prof.R
CASE <- Sys.getenv("CASE", "episodic-lma")
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2/perf/common.R")
cs <- case_setup(CASE); nd <- r22_nodes(CASE)
first <- timed_run(cs, seq(0, HORIZON, length.out = 100), gradient = FALSE, records = TRUE, label = "first")
x <- timed_run(cs, nd$S, label = "level0")
r <- timed_run(cs, nd$half, base = x, label = "replay")
saveRDS(list(first = first$cpu, level0 = x$cpu, replay = r$cpu, meta = list(first$meta, x$meta, r$meta)),
        Sys.getenv("OUT", "/dev/null"))
