# Tolerance moves per quantity, in eps, on schedules run at more than one tolerance with
# the current code. Prints each pair's moves and, where three tolerances share a
# schedule, the ratio of successive moves (p = 1 gives 2.86 for 3e-5, 1e-4, 3e-4).
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
AR <- file.path(DEV, "schedtest/adjmap/runs")
q_of <- function(n) { x <- readRDS(file.path(AR, paste0(n, ".rds"))); if (is.null(x$stand$elasticity) || !all(is.finite(x$stand$elasticity))) c(lnJ = log(x$stand$J)) else quantities(x) }
cost_of <- function(n) { x <- readRDS(file.path(AR, paste0(n, ".rds"))); c(rows = x$stand$rows, cpu = x$stand$cpu, sw = if (is.null(x$sweep_cpu)) NA else x$sweep_cpu, steps = length(x$stand$times)) }
G <- list(
  dry215 = c(`3e-5` = "val_c5g_c_dry", `1e-4` = "val_probe_tol1e4_dry", `3e-4` = "val_probe_tol3e4_dry"),
  dry331 = c(`3e-6` = "rp_Htight_dry", `3e-5` = "hybl_dy_dry_p0"),
  dry169 = c(`1e-4` = "val_a09_c_dry", `3e-4` = "val_a09h_c_dry"),
  dry_a09f = c(`1e-4` = "val_a09_f_dry", `3e-4` = "val_a09h_f_dry"),
  epi166 = c(`3e-5` = "val_c5g_c_episodic", `1e-4` = "val_probe_tol1e4_episodic", `3e-4` = "val_probe_tol3e4_episodic"),
  epi163 = c(`3e-5` = "val_a04_c_episodic", `1e-4` = "val_a04t_c_episodic"),
  epi226 = c(`3e-5` = "val_a04_f_episodic", `1e-4` = "val_a04t_f_episodic"),
  epi137 = c(`1e-4` = "val_a09_c_episodic", `3e-4` = "val_a09h_c_episodic"),
  epi206 = c(`1e-4` = "val_a09_f_episodic", `3e-4` = "val_a09h_f_episodic"),
  ld213 = c(`3e-5` = "val_a04_c_long-drought", `1e-4` = "val_fx_c_long-drought"),
  wet_a09c = c(`1e-4` = "val_a09_c_long-wet", `3e-4` = "val_a09h_c_long-wet"),
  wet_a09f = c(`1e-4` = "val_a09_f_long-wet", `3e-4` = "val_a09h_f_long-wet"))
MOVES <- list(); COSTS <- list()
for (g in names(G)) { ns <- G[[g]]; fs <- file.path(AR, paste0(ns, ".rds")); if (!all(file.exists(fs))) { cat(g, ": missing\n"); next }
  same <- sapply(ns, function(n) { S <- readRDS(file.path(AR, paste0(n, ".rds")))$node_times; sprintf("%d:%.8f", length(S), sum(S)) })
  if (length(unique(same)) > 1) { cat(g, ": schedules differ\n"); next }
  Q <- lapply(ns, q_of); k <- Reduce(intersect, lapply(Q, names)); e <- eps_vec(k)
  C <- t(sapply(ns, cost_of)); COSTS[[g]] <- C
  cat(sprintf("\n== %s (n %s): rows %s; cpu+sweep %s\n", g, same[1], paste(sprintf("%.3f", C[, "rows"] / C[1, "rows"]), collapse = " "),
    paste(sprintf("%.3f", (C[, "cpu"] + C[, "sw"]) / (C[1, "cpu"] + C[1, "sw"])), collapse = " ")))
  M <- sapply(2:length(ns), function(i) (Q[[i]][k] - Q[[i - 1]][k]) / e); M <- matrix(M, nrow = length(k), dimnames = list(k, paste(names(ns)[-length(ns)], names(ns)[-1], sep = "->")))
  MOVES[[g]] <- M
  o <- order(-apply(abs(M), 1, max)); top <- head(o, 12)
  cat(sprintf("  %d quantities; |move| max %s, rms %s\n", length(k), paste(sprintf("%.3f", apply(abs(M), 2, max)), collapse = " "), paste(sprintf("%.3f", sqrt(colMeans(M^2))), collapse = " ")))
  for (i in top) cat(sprintf("  %-28s %s%s\n", k[i], paste(sprintf("%+.3f", M[i, ]), collapse = "  "), if (ncol(M) == 2) sprintf("   ratio %+.2f", M[i, 2] / M[i, 1]) else "")) }
saveRDS(list(moves = MOVES, costs = COSTS), "/home/user/plant-dev/docs/measurements/schedule-search/round3/A/tolscale.rds")
