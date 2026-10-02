# Write jobs7.txt: the generalisation runs, in priority order.
comb <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb"
guard <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_guard"
lib3 <- file.path(comb, "lib3")
job <- function(script, name, lib, sched, extra = character()) {
  paste(c(script, file.path(comb, "logs", paste0(name, ".log")), paste0("PLANT_LIB=", lib),
          paste0("TIMES=", file.path(comb, "sched", paste0("t_", sched, ".rds"))), extra,
          paste0("OUT=", file.path(comb, "runs", paste0(name, ".rds")))), collapse = " ")
}
inv <- function(name, spread, sched, extra = character())
  job("inv_probe2.R", name, if (spread) lib3 else guard, sched, c(extra, if (spread) "PLANT_PROBE_SPREAD=8"))
lines <- c(
  # Q1: every quantity on the spread uniform ladder (u108 already running)
  job("run_record_probe.R", "full_spread_u215", lib3, "u215", c("TOL=3e-5", "ATOL=1e-4", "PLANT_PROBE_SPREAD=8")),
  job("run_record_probe.R", "full_spread_u429", lib3, "u429", c("TOL=3e-5", "ATOL=1e-4", "PLANT_PROBE_SPREAD=8")))
# Q2: other records, lma per node, lumped and spread, u108 and u215
for (r in c("long-wet", "episodic", "dry")) for (n in c("u108", "u215")) for (s in c(FALSE, TRUE))
  lines <- c(lines, inv(sprintf("rec_%s_%s_%s", r, if (s) "spread" else "lumped", n), s, n, paste0("REGIME=", r)))
# Q3: two more long-drought seeds, lma per node
for (sd in c(101, 103)) for (s in c(TRUE, FALSE)) for (n in c("u108", "u215", "u429"))
  lines <- c(lines, inv(sprintf("seed%d_%s_%s", sd, if (s) "spread" else "lumped", n), s, n, paste0("SEED=", sd)))
# Q4: spread on the graded ladder, and lumped G3 for the graded parts
for (g in c("ld_G1", "ld_G2", "ld_G3")) lines <- c(lines, inv(sprintf("graded_spread_%s", g), TRUE, g))
lines <- c(lines, inv("graded_lumped_ld_G3", FALSE, "ld_G3"))
# Q2, the constant record last: its uniform grids miss the founders' front
for (n in c("u108", "u215")) for (s in c(FALSE, TRUE))
  lines <- c(lines, inv(sprintf("rec_constant_%s_%s", if (s) "spread" else "lumped", n), s, n, "REGIME=constant"))
writeLines(lines, file.path(comb, "scripts", "jobs7.txt"))
cat(length(lines), "jobs\n")
