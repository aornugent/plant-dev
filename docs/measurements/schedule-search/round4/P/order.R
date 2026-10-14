# How the edge bias scales with spacing: the a09 c and f runs' errors projected on M (in10's move), dry.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
for (cs in c("dry")) { B <- pair(cs); x <- readRDS(file.path(POUT, "runs", sprintf("P_in10_%s.rds", cs))); q <- quantities(x); k <- intersect(B$k, names(q)); e <- eps_vec(k); M <- (q[k] - B$qc[k]) / e
  pc <- -sum(B$ec[k] * M) / sum(M^2); pf <- -sum(B$ef[k] * M) / sum(M^2)
  hc <- median(diff(sched(cs, "c"))[diff(sched(cs, "c")) > 20/365]); hf <- median(diff(sched(cs, "f"))[diff(sched(cs, "f")) > 20/365])
  cat(sprintf("%s: projection of error on -M: c %.2f, f %.2f, ratio %.2f | median open spacing c %.0f d f %.0f d ratio %.2f (first order predicts ratio = spacing ratio, second its square %.2f); proxy s %.2f\n", cs, pc, pf, pc / pf, hc * 365, hf * 365, hc / hf, (hc / hf)^2, B$s))
  rc <- B$ec[k] + pc * M; rf <- B$ef[k] + pf * M; cat(sprintf("   residual rms c %.3f f %.3f (ratio %.2f)\n", sqrt(mean(rc^2)), sqrt(mean(rf^2)), sqrt(mean(rc^2)) / sqrt(mean(rf^2)))) }
