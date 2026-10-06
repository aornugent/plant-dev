# How the crossing steps sit in time: runs of consecutive crossing steps, and
# for each crossing whether the steps either side are crossing steps too (so a
# crossing that moves to a neighbouring step stays in a cut step).
ev <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events/runs"
st <- readRDS(file.path(ev, "g_1e-4.rds"))$st
s <- readRDS(file.path(ev, "slq_1e-4.rds"))
rows <- sort(unique(s$row))
runs <- rle(diff(rows) == 1)
cat(sprintf("crossing steps %d; runs of consecutive crossing steps: %d; longest %d\n",
            length(rows), sum(!runs$values) + 1, max(runs$lengths[runs$values]) + 1))
isx <- function(r) r %in% rows
both <- isx(s$row - 1) & isx(s$row + 1)
before <- s$uc < 0.5
nb <- ifelse(before, isx(s$row - 1), isx(s$row + 1))
cat(sprintf("crossings whose nearer neighbouring step is a crossing step: %.1f%%; both neighbours: %.1f%%\n",
            100 * mean(nb), 100 * mean(both)))
k <- table(s$row)
cat(sprintf("crossings per crossing step: median %g, mean %.1f, 90%% %g, max %d; steps with 1 crossing %d\n",
            median(k), mean(k), quantile(k, .9), max(k), sum(k == 1)))
# Alive nodes per crossing step (members born before the step) for the row cost.
U108 <- seq(0, 107 * 40 / 108, length.out = 108)
alive <- sapply(rows, function(r) sum(U108 <= st$time[r]))
cat(sprintf("nodes alive at crossing steps: median %g, mean %.1f; crossing nodes / alive: median %.2f\n",
            median(alive), mean(alive), median(as.numeric(k) / alive)))
cat(sprintf("mean nodes alive over all steps (row width) %.1f\n", mean(sapply(st$time, function(t) sum(U108 <= t)))))
