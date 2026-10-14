# P1-P3: a09's pairs, real CPU against the rows model, and the extrapolated answer.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
rows <- list()
for (tag in c("a09", "a09h")) for (cs in ALL) { t2 <- if (tag == "a09h" && cs %in% LD) "a09hp" else tag
  P <- pair(cs, t2); if (is.null(P)) { cat(tag, cs, "missing\n"); next }
  coarse <- all(abs(P$d / (1 - P$s)) < 1); err <- if (coarse) P$ec else P$ef; sest <- if (coarse) P$d / (1 - P$s) else P$d * P$s / (1 - P$s)
  ex <- P$ec - P$d / (1 - P$s)          # extrapolated from c and the move
  cr <- crit(err, sest)
  rows[[length(rows) + 1]] <- data.frame(tag = t2, case = cs, s = round(P$s, 3), commit = if (coarse) "c" else "f", pass = all(cr),
    worst_c = round(max(abs(P$ec)), 2), worst_f = round(max(abs(P$ef)), 2), worst_ex = round(max(abs(ex)), 2),
    rms_c = round(sqrt(mean(P$ec^2)), 3), rms_ex = round(sqrt(mean(ex^2)), 3),
    T = round(P$Tc + P$Tf + 2 * (if (coarse) P$Tc else P$Tf)), cpuT = round(P$cpu_c + P$cpu_f + 2 * (if (coarse) P$cpu_c else P$cpu_f)),
    rc = round(P$cpu_c / P$Tc, 2), rf = round(P$cpu_f / P$Tf, 2), fc_model = round(P$Tf / P$Tc, 2), fc_cpu = round(P$cpu_f / P$cpu_c, 2),
    swp_c = round(P$xc$sweep_cpu / P$xc$stand$cpu, 2)) }
d <- do.call(rbind, rows); print(d, row.names = FALSE)
for (tg in unique(d$tag)) cat(tg, ": T all ten", sum(d$T[d$tag == tg]), " training", sum(d$T[d$tag == tg & d$case %in% names(CASES)]), " real-CPU T", sum(d$cpuT[d$tag == tg]), "\n")
saveRDS(d, file.path(OUT, "base.rds"))
