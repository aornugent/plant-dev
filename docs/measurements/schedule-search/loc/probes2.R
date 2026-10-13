# Tail edges dropped after 25 and 30 (tol 1e-4), against the tol 1e-4 base.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
for (case in c("dry", "episodic")) { ref <- reference(case); b <- readRDS(file.path(AR, sprintf("val_probe_tol1e4_%s.rds", case))); qb <- quantities(b)
  for (p in c("noedge25", "noedge30")) { x <- readRDS(file.path(AR, sprintf("val_probe_%s_%s.rds", p, case))); q <- quantities(x); k <- Reduce(intersect, list(names(ref), names(qb), names(q))); e <- eps_vec(k)
    mv <- (q[k] - qb[k]) / e; eb <- (qb[k] - ref[k]) / e; ex <- (q[k] - ref[k]) / e; o <- order(-abs(mv))[1:3]
    cat(sprintf("%-9s %-9s rows %.3f of base | moves max %.2f, over 0.1: %d (toward ref %d) | rms err %.3f -> %.3f | %s\n", case, p, x$stand$rows / b$stand$rows,
      max(abs(mv)), sum(abs(mv) > 0.1), sum(abs(ex[abs(mv) > 0.1]) < abs(eb[abs(mv) > 0.1])), sqrt(mean(eb^2)), sqrt(mean(ex^2)), paste(sprintf("%s %+.2f", k[o], mv[o]), collapse = ", "))) } }
