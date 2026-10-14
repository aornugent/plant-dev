# mkclass.R CASE: a09's committed schedule with one class of interval bisected, per class:
# F founders (before b1), O after an opening edge, C before a closing edge, S a spell of
# one interval (both), G a shut gap, I every other interval (spell interiors, after 25).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
cs <- commandArgs(TRUE)[1]; out <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/sched"
S <- sched(cs, "c"); et <- edge_table(cs); b1 <- pilot_of(cs)$b1; lo <- S[-length(S)]; hi <- S[-1]
at <- function(x, set) vapply(x, function(v) any(abs(set - v) < 1e-7), TRUE)
op <- at(lo, et$b[et$opening]); cl <- at(hi, et$b[!et$opening]); gap <- at(lo, et$b[!et$opening]) & at(hi, et$b[et$opening])
cls <- ifelse(hi <= b1 + 1e-9, "F", ifelse(gap, "G", ifelse(op & cl, "S", ifelse(op, "O", ifelse(cl, "C", "I")))))
E <- readRDS(file.path(R, sprintf("val_a09_c_%s.rds", cs)))$stand$nodes$establishment[seq_along(lo)]
EA <- tryCatch(ag_run(sprintf("AG_a09c_%s", cs))$stand$nodes$establishment[seq_along(lo)], error = function(e) NA * E)
for (k in c("F", "O", "C", "S", "G", "I")) { m <- cls == k
  saveRDS(sort(c(S, (lo[m] + hi[m]) / 2)), file.path(out, sprintf("a09b%s_%s.rds", k, cs)))
  cat(sprintf("%s: %3d intervals, median %5.1f d, establishment lib19 %.3f libAG %.3f\n", k, sum(m), median((hi[m] - lo[m]) * 365), sum(E[m]) / sum(E), sum(EA[m]) / sum(EA))) }
