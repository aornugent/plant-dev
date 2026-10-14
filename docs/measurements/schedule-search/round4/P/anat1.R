source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
summ <- function(A, lab) { m <- A$E > 0 & A$open > 0
  cat(sprintf("%-32s intervals %3d with estab %3d | mixed (open+shut) %3d | gap_lo>5d %3d (E %.4f) gap_hi>5d %3d (E %.4f) | E total %.3f | u<1/3 or >2/3: %d (E %.4f)\n", lab, nrow(A), sum(m), sum(m & A$shut > 0.5),
    sum(m & A$gap_lo > 5), sum(A$E[m & A$gap_lo > 5]), sum(m & A$gap_hi > 5), sum(A$E[m & A$gap_hi > 5]), sum(A$E), sum(m & (A$u < 1/3 | A$u > 2/3)), sum(A$E[m & (A$u < 1/3 | A$u > 2/3)]))) }
for (pr in list(c("dry","dry"), c("dry-p50","dry-p50"), c("dry","dry-p50"), c("episodic","episodic"), c("episodic-lma","episodic-lma"), c("episodic","episodic-lma"))) {
  S <- sched(pr[1]); S <- S[S < 25]; summ(anatomy(S, pr[2]), sprintf("%s grid, %s creation", pr[1], pr[2])) }
