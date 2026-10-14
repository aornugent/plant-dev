# mknest.R CASE: nested checks for a case's committed schedules (every committed node kept).
# a09nb: a09's committed schedule with every interval bisected.
# insnb: the 12-day inset with every interval inside a spell bisected, and each interval
# that spans a shut gap given the two nodes at half the inset, so its strips still
# interpolate between nodes inside spells.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
cs <- commandArgs(TRUE)[1]; out <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/sched"; dir.create(out, FALSE, TRUE)
bisect <- function(S) sort(c(S, (S[-1] + S[-length(S)]) / 2))
a <- sched(cs, "c"); saveRDS(bisect(a), file.path(out, sprintf("a09nb_%s.rds", cs)))
S <- readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))); et <- edge_table(cs); d <- 12 / 365
lo <- S[-length(S)]; hi <- S[-1]
spans <- vapply(seq_along(lo), function(i) any(et$b > lo[i] & et$b < hi[i]), TRUE)
half <- ifelse(et$spell < 2 * 12 + 1, et$spell / 4, 6) / 365
strip <- et$b + ifelse(et$opening, half, -half)
F <- sort(c(S, (lo[!spans] + hi[!spans]) / 2, strip)); F <- F[c(TRUE, diff(F) > 1e-6)]
saveRDS(F, file.path(out, sprintf("insnb_%s.rds", cs)))
cat(sprintf("%s: a09 c %d -> nb %d | inset c %d -> nb %d (gap-spanning intervals %d, strip nodes %d); inset c nodes kept %s\n", cs, length(a), length(bisect(a)),
  length(S), length(F), sum(spans), length(strip), all(vapply(S, function(s) any(abs(F - s) < 1e-9), TRUE))))
