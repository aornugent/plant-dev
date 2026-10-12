# The scorer's errors for the real G0 and G1 schedules against the real runs' errors.
source("/home/user/plant-dev/harness/schedule/anyscore.R")
for (case in commandArgs(TRUE)) { cd <- prepare(case)
  for (n in c("G0", "G1")) { x <- readRDS(file.path(AR, sprintf("loc_%s_%s.rds", n, case))); q <- quantities(x); k <- intersect(cd$Qs, names(q))
    real <- (q[k] - cd$ref[k]) / eps_vec(k); pr <- sim(cd, x$node_times, case)$err[k]
    cat(sprintf("%-13s %s: rms miss %.3f, max %.2f (%s); real worst %.2f, scored worst %.2f\n", case, n, sqrt(mean((pr - real)^2)), max(abs(pr - real)), k[which.max(abs(pr - real))], max(abs(real)), max(abs(pr)))) } }
