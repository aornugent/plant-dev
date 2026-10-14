# mkins75.R CASE: the check's inset scaled with the check's spacing ratio: a09's check
# schedule with every edge node moved 12/1.6 = 7.5 days into its spell (P's inset_rule).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
cs <- commandArgs(TRUE)[1]; out <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/sched"
f <- inset_rule(sched(cs, "f"), cs, d = 12 / 1.6); saveRDS(as.numeric(f), file.path(out, sprintf("ins75f_%s.rds", cs)))
cat(sprintf("%s: check with a 7.5-day inset, %d nodes (12-day check: %d)\n", cs, length(f), length(readRDS(file.path(POUT, "sched", sprintf("insf_%s.rds", cs))))))
