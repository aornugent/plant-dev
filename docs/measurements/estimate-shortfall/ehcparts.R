# The one-panel ladder (nested, 1..64 intervals over 7.985-8.519): each level's move to
# the next, split into own (interpolation + establishment) and field (effect at the
# coarser run's nodes), with the field split into the panel's own nodes and the rest.
source("/home/user/plant-dev/harness/node_parts.R")
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
Q <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/placed2/runs"
n <- c("01", "02", "04", "08", "16", "32", "64"); r <- lapply(n, function(k) nodes_of(readRDS(file.path(Q, sprintf("rc_ehc_%s_episodic.rds", k)))))
for (i in 1:6) { a <- r[[i]]; b <- r[[i + 1]]; pm <- panel_moves(a, b); J <- sum(a$w * a$offspring)
  inp <- a$birth >= 7.985 & a$birth <= 8.519
  cat(sprintf("%2s -> %2s: total %+.4f | own %+.4f | field at panel nodes %+.4f, founders (b<3.7) %+.4f, other %+.4f eps\n", n[i], n[i + 1],
    sum(pm$field + pm$interpolation + pm$establishment) / J / .025, sum(pm$interpolation + pm$establishment) / J / .025,
    sum(pm$field[inp]) / J / .025, sum(pm$field[a$birth < 3.7]) / J / .025, sum(pm$field[!inp & a$birth >= 3.7]) / J / .025)) }
