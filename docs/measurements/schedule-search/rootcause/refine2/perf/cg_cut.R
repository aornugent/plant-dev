# A short forward (and optionally its sweep) for counting calls under callgrind:
#   LIFETIME=2 CASE=episodic-lma GRAD=1 PLANT_LIB=<lib> valgrind --tool=callgrind exec/R -f cg_cut.R
CASE <- Sys.getenv("CASE", "episodic-lma")
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2/perf/common.R")
cs <- case_setup(CASE)
x <- timed_run(cs, seq(0, HORIZON, length.out = 12), gradient = Sys.getenv("GRAD") == "1", label = "cut")
if (nzchar(Sys.getenv("OUT"))) saveRDS(list(J = x$stand$J, times = x$stand$times, elasticity = x$stand$elasticity, cpu = x$cpu), Sys.getenv("OUT"))
