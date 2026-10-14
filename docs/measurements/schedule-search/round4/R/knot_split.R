# knot_split.R: in a knot-stopping run, which knot-ending steps substepped the soil?
# A knot inside a substepped step can be taken by the soil's substeps; one inside a
# coupled step still ends that step. Reads only the saved run (no new run).
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
suppressMessages(source("/home/user/plant-dev/harness/long_drought.R"))
args <- commandArgs(TRUE)
for (a in args) {
  r <- readRDS(file.path(O, a)); reg <- r$setting$regime; seed <- r$setting$seed
  scen <- sprintf("%s, seed %d", reg, seed); RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[reg]], list(seed = seed))
  k <- active_knots(scen); t <- r$stand$times; n <- length(t)
  sub <- vapply(r$stand$input_slopes, length, 0L) > 0          # per row; row 1 is the start
  ends_on_knot <- round(t, 10) %in% round(k, 10)
  i <- which(ends_on_knot[-1]) + 1                                # rows (steps) ending on a knot
  alive <- vapply(t[-n], function(s) sum(r$node_times <= s) + 1, 0)  # rows per step
  w <- alive[i - 1]
  cat(sprintf("%-28s steps %5d, substepped %4.1f%% | knot-ending %4d (%4.1f%% of steps, %4.1f%% of rows): substepped %4.1f%% (rows %4.1f%%); next step also substepped %4.1f%%\n",
    basename(a), n - 1, 100 * mean(sub[-1]), length(i), 100 * length(i) / (n - 1), 100 * sum(w) / sum(alive),
    100 * mean(sub[i]), 100 * sum(w[sub[i]]) / sum(w), 100 * mean(sub[i][i < n] & sub[pmin(i + 1, n)][i < n])))
}
