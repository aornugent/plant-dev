# Default-shaped start: L0 plus node_schedule_times_default's nodes over the
# founders' window [0, b1).  Rscript mkdft.R TAG REC
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
args <- commandArgs(TRUE); tag <- args[1]; rec <- args[2]
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
cr <- readRDS(sprintf("%s/placed2/runs/m_%s_f_%s.rds", S, tag, rec))$stand$creation
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]; b1 <- ed[op[e][-length(e)] & ed > 0][1]
L0 <- readRDS(sprintf("%s/matrix/%s_%s.rds", S, tag, rec)); d <- plant::node_schedule_times_default(40)
s <- sort(unique(c(L0, d[d < b1]))); s <- s[c(TRUE, diff(s) > 1e-9)]
saveRDS(s, sprintf("%s/start/dft_%s_%s.rds", S, tag, rec)); cat(sprintf("%s %s: b1 %.3f, %d nodes\n", tag, rec, b1, length(s)))
