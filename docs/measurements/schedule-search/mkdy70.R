# dy with late spacing 70 d throughout (Phase 1 of plan-schedule-search.md): 16 even nodes over
# the founders' window [0, b1), 70 d after; each first-pass edge replaces any base node within half the
# local spacing; base nodes born while establishment is shut dropped.  Rscript mkdy.R TAG REC
a <- commandArgs(TRUE); S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
cr <- readRDS(sprintf("%s/placed2/runs/m_%s_f_%s.rds", S, a[1], a[2]))$stand$creation
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]; shut_e <- op[e][-length(e)]
ed <- ed[ed > 0 & ed < 39.6]; b1 <- ed[shut_e[seq_along(ed)]][1]
shut <- approxfun(c(cr$start, tail(cr$end, 1)), c(as.numeric(!op), tail(as.numeric(!op), 1)), method = "constant", rule = 2)
base <- c(seq(0, b1, length.out = 17)[-17], seq(b1, 39.6, by = 70 / 365))
hloc <- function(t) ifelse(t < b1, b1 / 16, 70 / 365)
keep <- vapply(base, function(t) all(abs(ed - t) > hloc(t) / 2), TRUE) & shut(base) < 0.5
s <- sort(unique(c(base[keep], ed))); s <- s[c(TRUE, diff(s) > 1e-6)]
saveRDS(s, sprintf("%s/p1/dy70_%s_%s.rds", S, a[1], a[2])); cat(sprintf("%s %s: b1 %.3f, %d base kept of %d, %d edges, %d nodes; smallest interval %.2f d\n", a[1], a[2], b1, sum(keep), length(base), length(ed), length(s), min(diff(s)) * 365))
