# Splits each tolerance step's move into a part shared by every schedule of one record
# (systematic, what a check at another tolerance would read) and a part that differs
# between schedules (jitter). Each pair is one schedule at two tolerances.
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
AR <- file.path(DEV, "schedtest/adjmap/runs")
q_of <- function(n) { x <- readRDS(file.path(AR, paste0(n, ".rds"))); if (is.null(x$stand$elasticity) || !all(is.finite(x$stand$elasticity))) NULL else quantities(x) }
P <- list(
  `dry 1e-4->3e-4` = list(c("val_probe_tol1e4_dry", "val_probe_tol3e4_dry"), c("val_a09_c_dry", "val_a09h_c_dry"), c("val_a09_f_dry", "val_a09h_f_dry")),
  `dry 3e-5->1e-4` = list(c("val_c5g_c_dry", "val_probe_tol1e4_dry")),
  `episodic 3e-5->1e-4` = list(c("val_c5g_c_episodic", "val_probe_tol1e4_episodic"), c("val_a04_c_episodic", "val_a04t_c_episodic"), c("val_a04_f_episodic", "val_a04t_f_episodic")),
  `episodic 1e-4->3e-4` = list(c("val_a09_c_episodic", "val_a09h_c_episodic"), c("val_a09_f_episodic", "val_a09h_f_episodic")),
  `long-wet 1e-4->3e-4` = list(c("val_a09_c_long-wet", "val_a09h_c_long-wet"), c("val_a09_f_long-wet", "val_a09h_f_long-wet")),
  `long-drought 3e-5->1e-4` = list(c("val_a04_c_long-drought", "val_fx_c_long-drought")),
  `long-drought 1e-4->3e-4` = list(c("val_a09_c_long-drought", "val_a09h_c_long-drought"), c("val_a09_f_long-drought", "val_a09h_f_long-drought")),
  `lma 1e-4->3e-4` = list(c("val_a09_c_episodic-lma", "val_a09h_c_episodic-lma"), c("val_a09_f_episodic-lma", "val_a09h_f_episodic-lma")),
  `dry-flat 3e-5->1e-4` = list(c("val_c5g_c_dry-flat", "val_a04t_c_dry-flat")),
  `dry-flat 1e-4->3e-4` = list(c("val_a09_c_dry-flat", "val_a09h_c_dry-flat"), c("val_a09_f_dry-flat", "val_a09h_f_dry-flat")),
  `dry-p50 1e-4->3e-4` = list(c("val_a09_c_dry-p50", "val_a09h_c_dry-p50"), c("val_a09_f_dry-p50", "val_a09h_f_dry-p50")),
  `dry 3e-6->3e-5` = list(c("rp_Htight_dry", "hybl_dy_dry_p0")))
OUT <- list()
for (nm in names(P)) {
  M <- list(); for (pr in P[[nm]]) { if (!all(file.exists(file.path(AR, paste0(pr, ".rds"))))) next
    a <- q_of(pr[1]); b <- q_of(pr[2]); if (is.null(a) || is.null(b)) next; k <- intersect(names(a), names(b))
    M[[pr[2]]] <- (b[k] - a[k]) / eps_vec(k) }
  if (!length(M)) { cat(nm, ": no complete pair yet\n"); next }
  k <- Reduce(intersect, lapply(M, names)); k <- setdiff(k, "rooting_depth_max"); X <- sapply(M, function(m) m[k]); X <- matrix(X, nrow = length(k), dimnames = list(k, names(M)))
  OUT[[nm]] <- X
  cat(sprintf("\n== %s: %d schedule(s); per-schedule rms %s, max %s\n", nm, ncol(X), paste(sprintf("%.3f", sqrt(colMeans(X^2))), collapse = " "), paste(sprintf("%.3f", apply(abs(X), 2, max)), collapse = " ")))
  if (ncol(X) >= 2) { cm <- rowMeans(X); res <- X - cm; sj <- sqrt(sum(res^2) / (length(k) * (ncol(X) - 1)))
    r <- cor(X); cat(sprintf("  correlation between schedules %s; shared part rms %.3f (max %.3f); per-schedule jitter rms %.3f\n",
      paste(sprintf("%.2f", r[upper.tri(r)]), collapse = " "), sqrt(mean(cm^2)), max(abs(cm)), sj))
    o <- head(order(-abs(cm)), 10); for (i in o) cat(sprintf("  %-26s shared %+.3f | %s\n", k[i], cm[i], paste(sprintf("%+.3f", X[i, ]), collapse = " "))) } }
saveRDS(OUT, "/home/user/plant-dev/docs/measurements/schedule-search/round3/A/tolsys.rds")
