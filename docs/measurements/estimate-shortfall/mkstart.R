# Start rule: L0 plus 16 even nodes over the founders' window [0, b1), b1 the first
# closing in the first pass's creation record.  Rscript mkstart.R TAG REC
args <- commandArgs(TRUE); tag <- args[1]; rec <- args[2]
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
cr <- readRDS(sprintf("%s/placed2/runs/m_%s_f_%s.rds", S, tag, rec))$stand$creation
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]; shuts <- op[e][-length(e)]
b1 <- ed[shuts & ed > 0][1]
L0 <- readRDS(sprintf("%s/matrix/%s_%s.rds", S, tag, rec))
s <- sort(unique(c(L0, seq(0, b1, length.out = 17)[-17]))); s <- s[c(TRUE, diff(s) > 1e-6)]
saveRDS(s, sprintf("%s/start/s16_%s_%s.rds", S, tag, rec))
cat(sprintf("%s %s: b1 %.3f, L0 %d -> %d nodes\n", tag, rec, b1, length(L0), length(s)))
