# Check a field_snap.R output: the reconstructed lumped field against plant's own
# compute_competition, and the spline against exp(-A).
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb/scripts/field_lib.R")
x <- readRDS(commandArgs(TRUE)[1])
for (s in x$snaps) {
  A <- field_A(s, s$z)
  E <- exp(-s$A)
  cat(sprintf("t %.4f: %d nodes, top %.3f m | max |A_rec - A| %.3g (max A %.3g) | weights match %.3g | max |E_spline - exp(-A)| %.3g\n",
              s$time, length(s$height) - 1, max(s$height), max(abs(A - s$A)), max(s$A),
              max(abs(s$lo + s$hi - s$w)), max(abs(s$E_spline - E))))
}
