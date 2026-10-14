# mkgap.R CASE...: a09's check schedule with every interval that spans a g-gap and
# carries establishment on the run's own weight bisected (the committed run unchanged).
# Weight: E recorded on AG_a09c_<case> (libAG); on lib19 those intervals carry none, so
# the rule adds nothing there. Writes AG_out/sched/a09fg_<case>.rds.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
for (cs in commandArgs(TRUE)) { et <- edge_table(cs); cl <- et$b[!et$opening]; G <- ag_run(sprintf("AG_a09c_%s", cs))$gate; G <- G[!duplicated(G$time, fromLast = TRUE), ]
  Ew <- function(lo, hi) { z <- G$time > lo & G$time <= hi; if (!any(z)) return(0); t <- c(lo, G$time[z]); sum(diff(t) * G$E[z]) }
  S <- sort(sched(cs, "f")); lo <- S[-length(S)]; hi <- S[-1]
  gap <- vapply(seq_along(lo), function(i) lo[i] < 25 && any(cl > lo[i] - 1e-9 & cl < hi[i] - 1e-9), TRUE)
  w <- vapply(seq_along(lo), function(i) if (gap[i]) Ew(lo[i], hi[i]) else 0, 0)
  add <- (lo + hi)[gap & w > 0] / 2; out <- sort(c(S, add)); saveRDS(out, file.path(AGOUT, "sched", sprintf("a09fg_%s.rds", cs)))
  spell_w <- median(vapply(which(!gap & lo > et$b[1] & hi < 25), function(i) Ew(lo[i], hi[i]), 0))
  cat(sprintf("%-13s a09 f %d -> %d nodes (+%d gap bisections); gap intervals' E: median %.4f yr, min %.4f (a spell interval's median %.4f)\n", cs, length(S), length(out), length(add), median(w[gap]), min(w[gap]), spell_w)) }
