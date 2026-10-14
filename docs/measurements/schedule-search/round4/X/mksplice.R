# mksplice.R A B T OUT: a step sequence to replay, A's accepted steps
# up to the step end nearest T that both runs share, and B's after it.
a <- commandArgs(TRUE); A <- readRDS(a[1])$stand; B <- readRDS(a[2])$stand; T <- as.numeric(a[3])
both <- A$times[vapply(A$times, function(t) any(abs(B$times - t) < 1e-12), TRUE)]; T <- both[which.min(abs(both - T))]
ia <- which(A$times <= T + 1e-12); ib <- which(B$times > T + 1e-12)
pick <- function(f) c(A[[f]][ia], B[[f]][ib])
saveRDS(list(stand = list(times = pick("times"), sizes = pick("sizes"), input_slopes = pick("input_slopes"), substep_ends = pick("substep_ends"))), a[4])
cat(sprintf("splice at %.4f: %d steps of A, %d of B\n", T, length(ia), length(ib)))
