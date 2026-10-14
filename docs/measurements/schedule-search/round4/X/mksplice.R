# mksplice.R A B T OUT: a step sequence to replay, A's accepted steps up to the node
# introduced nearest T and B's after it (both runs stop at every introduction).
a <- commandArgs(TRUE); A <- readRDS(a[1])$stand; B <- readRDS(a[2])$stand; T <- as.numeric(a[3])
T <- A$times[which.min(abs(A$times - T))]; stopifnot(any(abs(B$times - T) < 1e-12))
ia <- which(A$times <= T + 1e-12); ib <- which(B$times > T + 1e-12)
pick <- function(f) c(A[[f]][ia], B[[f]][ib])
saveRDS(list(stand = list(times = pick("times"), sizes = pick("sizes"), input_slopes = pick("input_slopes"), substep_ends = pick("substep_ends"))), a[4])
cat(sprintf("splice at %.4f: %d steps of A, %d of B\n", T, length(ia), length(ib)))
