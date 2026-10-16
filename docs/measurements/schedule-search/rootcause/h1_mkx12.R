# h1_mkx12.R CASE...: diagnostic for H1's misses. The coarse companion's spacing (as
# h1_mkcoarse.R) with the committed run's 12-day inset instead of 19.2 d, to separate the
# inset's distance from the spacing.
Sys.setenv(BG = 90, R = 1.6)
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
H1 <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/h1"
r <- 1.6; cap0 <- cap_of
late_out <- function(S, p) { late <- round(p$edges[p$edges > 25], 10); S[!(round(S, 10) %in% late)] }
for (cs in commandArgs(TRUE)) { p <- pilot_of(cs); h <- alg$hfun_of(p)
  cap_of <- function(p, lo, hi) r * cap0(p, lo, hi); Sx <- late_out(build_graded(p, function(b) r * h(b)), p); cap_of <- cap0
  I <- inset_rule(Sx, cs, d = 12); saveRDS(as.numeric(I), file.path(H1, "sched", sprintf("insx12_%s.rds", cs)))
  cat(sprintf("%-13s coarse spacing, 12-d inset: %d nodes (19.2-d inset %d)\n", cs, length(I), length(readRDS(file.path(H1, "sched", sprintf("insx_%s.rds", cs)))))) }
