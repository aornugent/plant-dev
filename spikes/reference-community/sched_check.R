# One recording at (LNB, X) on the schedule NODES / EARLY / EARLY_RATIO: F,
# F_lnb and the cut g, to compare schedules at one point.
#   LNB=3.595 X=0,0,0 EARLY=20 EARLY_RATIO=1.41421356 Rscript sched_check.R
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
lnb <- as.numeric(Sys.getenv("LNB", "3.595"))
x <- as.numeric(strsplit(Sys.getenv("X", "0,0,0"), ",")[[1]])
tag <- sprintf("%s_n%d_e%d_r%.4f_lnb%.4f_%s", REGIME, NODES, EARLY, EARLY_RATIO, lnb,
               paste(sprintf("%+.4f", x), collapse = ""))
r <- record(lnb, x, file = file.path(TMP, "sched", paste0(tag, ".rds")))
cat(sprintf("%s introductions %d first %.2e: F %+.5f F_lnb %.4f g %s steps %d %.0fs\n",
            tag, length(TIMES), TIMES[2], r$F, r$F_lnb, paste(sprintf("%+.3f", r$g), collapse = " "),
            r$steps, r$secs_run + r$secs_sweep))
