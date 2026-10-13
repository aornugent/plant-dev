# Each probe against its base (c05_graded's committed run): move per quantity in eps, error vs reference, rows.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
for (case in c("dry", "episodic")) { ref <- reference(case); b <- readRDS(file.path(AR, sprintf("val_c5g_c_%s.rds", case))); qb <- quantities(b)
  for (p in c("tol1e4", "tol3e4", "noedge", "wide")) { f <- file.path(AR, sprintf("val_probe_%s_%s.rds", p, case)); if (!file.exists(f)) next
    x <- readRDS(f); if (is.null(x$stand$elasticity)) next; q <- quantities(x); k <- Reduce(intersect, list(names(ref), names(qb), names(q))); e <- eps_vec(k)
    mv <- (q[k] - qb[k]) / e; er <- (q[k] - ref[k]) / e; eb <- (qb[k] - ref[k]) / e; o <- order(-abs(mv))[1:3]
    cat(sprintf("%-9s %-7s rows %.2f, cpu %.2f of base | move max %.2f, rms %.3f (%s) | worst err %.2f (base %.2f)\n", case, p, x$stand$rows / b$stand$rows,
      (x$stand$cpu + x$sweep_cpu) / (b$stand$cpu + b$sweep_cpu), max(abs(mv)), sqrt(mean(mv^2)), paste(sprintf("%s %+.2f", k[o], mv[o]), collapse = ", "), max(abs(er)), max(abs(eb)))) } }
