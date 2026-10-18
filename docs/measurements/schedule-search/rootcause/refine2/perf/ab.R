# A/B of the loop's runs on R22's node times.
#   PLANT_LIB=<lib> Rscript ab.R CASE MODE OUT [BASE]
# MODE loop:   first run, level 0, replay in one process (refine_schedule's sequence)
#      nofirst: level 0 then replay in one process
#      S:       level 0 alone
#      half:    the replay alone, pinned to BASE's steps (an S output)
# GC=1 calls gc() before each run.
a <- commandArgs(TRUE); CASE <- a[1]; MODE <- a[2]; OUT <- a[3]
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2/perf/common.R")
cs <- case_setup(CASE); nd <- r22_nodes(CASE)
g <- function() if (Sys.getenv("GC") == "1") invisible(gc())
res <- list(case = CASE, mode = MODE, lib = Sys.getenv("PLANT_LIB"), gc = Sys.getenv("GC"))
strip <- function(x) { x$stand$input_slopes <- x$stand$substep_ends <- NULL; x }
if (MODE == "loop") {
  g(); res$first <- strip(timed_run(cs, seq(0, HORIZON, length.out = 100), gradient = FALSE, records = TRUE, label = "first"))
}
if (MODE %in% c("loop", "nofirst", "S")) {
  g(); x <- timed_run(cs, nd$S, label = "level0"); res$level0 <- strip(x)
}
if (MODE %in% c("loop", "nofirst")) {
  g(); res$replay <- strip(timed_run(cs, nd$half, base = x, label = "replay"))
}
if (MODE == "S") saveRDS(x$stand, paste0(OUT, ".base"))
if (MODE == "half") {
  base <- list(stand = readRDS(a[4]))
  g(); res$replay <- strip(timed_run(cs, nd$half, base = base, label = "replay"))
}
saveRDS(res, OUT)
