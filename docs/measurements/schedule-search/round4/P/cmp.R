# cmp.R CASE RUN...: each P run against a09's committed run of CASE (moves and errors in eps).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
a <- commandArgs(TRUE); cs <- a[1]; B <- pair(cs)
for (nm in a[-1]) { f <- file.path(POUT, "runs", paste0(nm, ".rds")); if (!file.exists(f)) f <- file.path(R, paste0(nm, ".rds")); x <- readRDS(f)
  q <- quantities(x); k <- intersect(B$k, names(q)); e <- eps_vec(k); err <- (q[k] - B$ref[k]) / e; mv <- err - B$ec[k]; el <- setdiff(k, "lnJ")
  cat(sprintf("%-18s n %3d (base %3d) rows %.0fk (%.0fk) cpu %.0f (%.0f) | move: lnJ %+.3f, max %.2f (%s), rms %.3f, n>0.1 %d, n>0.3 %d | error worst %.2f (%s; base %.2f), rms %.3f (base %.3f)\n",
    nm, length(x$node_times), length(B$xc$node_times), x$stand$rows / 1e3, B$xc$stand$rows / 1e3, cpu_of(x), B$cpu_c, mv["lnJ"], max(abs(mv)), k[which.max(abs(mv))], sqrt(mean(mv^2)),
    sum(abs(mv) > 0.1), sum(abs(mv) > 0.3), max(abs(err)), k[which.max(abs(err))], max(abs(B$ec[k])), sqrt(mean(err^2)), sqrt(mean(B$ec[k]^2))))
  o <- order(-abs(mv))[1:6]; cat("   top moves:", paste(sprintf("%s %+.2f (err %+.2f, base %+.2f, est %+.2f)", k[o], mv[o], err[o], B$ec[k][o], (B$d / (1 - B$s))[k][o]), collapse = "; "), "\n")
  cat(sprintf("   corr(move, base error) %.2f, corr(move, base estimate) %.2f\n", cor(mv, B$ec[k]), cor(mv, (B$d / (1 - B$s))[k]))) }
