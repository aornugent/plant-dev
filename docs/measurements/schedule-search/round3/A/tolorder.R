# The order of dry's tolerance error. u is the shared direction of dry's 1e-4 -> 3e-4
# move (two schedules); each other move is projected on u. A power law E = c t^p gives
# a ratio of the projected move to the 1e-4 -> 3e-4 one of (t2^p - t1^p)/(3e-4^p - 1e-4^p).
X <- readRDS("/home/user/plant-dev/docs/measurements/schedule-search/round3/A/tolsys.rds")
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
AR <- file.path(DEV, "schedtest/adjmap/runs")
U <- X[["dry 1e-4->3e-4"]]; u <- rowMeans(U); a3 <- sqrt(sum(u^2)); un <- u / a3
mv <- function(a, b) { qa <- quantities(readRDS(file.path(AR, paste0(a, ".rds")))); qb <- quantities(readRDS(file.path(AR, paste0(b, ".rds")))); k <- names(u); (qb[k] - qa[k]) / eps_vec(k) }
pred <- function(t1, t2, p) (t2^p - t1^p) / (3e-4^p - 1e-4^p)
proj <- function(lab, m, t1, t2) { a <- sum(m * un); r <- m - a * un
  pr <- sapply(c(0.5, 1, 2, 3), function(p) pred(t1, t2, p))
  cat(sprintf("%-36s along u %+.3f (ratio %+.2f; p=0.5,1,2,3 give %s) | off u rms %.3f; on-u share of |m|^2 %.2f\n", lab, a, a / a3,
    paste(sprintf("%.2f", pr), collapse = ","), sqrt(mean(r^2)), a^2 / sum(m^2))) }
cat(sprintf("u: |u| %.3f over %d quantities\n", a3, length(u)))
for (j in seq_len(ncol(U))) proj(paste("dry 1e-4->3e-4,", colnames(U)[j]), U[, j], 1e-4, 3e-4)
proj("dry 3e-5->1e-4 (c5g)", mv("val_c5g_c_dry", "val_probe_tol1e4_dry"), 3e-5, 1e-4)
proj("dry 3e-5->3e-4 (c5g)", mv("val_c5g_c_dry", "val_probe_tol3e4_dry"), 3e-5, 3e-4)
proj("dry 3e-6->3e-5 (n331)", mv("rp_Htight_dry", "hybl_dy_dry_p0"), 3e-6, 3e-5)
for (case in c("episodic", "long-drought")) {
  pr <- switch(case, episodic = list(c("val_c5g_c_episodic", "val_probe_tol1e4_episodic", 3e-5, 1e-4), c("val_a04_c_episodic", "val_a04t_c_episodic", 3e-5, 1e-4),
    c("val_a04_f_episodic", "val_a04t_f_episodic", 3e-5, 1e-4), c("val_a09_c_episodic", "val_a09h_c_episodic", 1e-4, 3e-4), c("val_a09_f_episodic", "val_a09h_f_episodic", 1e-4, 3e-4)),
    `long-drought` = list(c("val_a04_c_long-drought", "val_fx_c_long-drought", 3e-5, 1e-4)))
  for (p in pr) proj(sprintf("%s %s->%s %s", case, p[3], p[4], p[2]), mv(p[1], p[2]), as.numeric(p[3]), as.numeric(p[4])) }
# ln J alone, long drought's u108 ladder (forward only): move from 1e-7, in eps.
SC <- file.path(DEV, "sc/runs"); for (m in c("plain", "split")) { t <- c("1e-7", "1e-5", "3e-5", "1e-4", "3e-4", "1e-3")
  J <- sapply(t, function(x) { f <- file.path(SC, sprintf("%s_%s.rds", m, x)); if (file.exists(f)) readRDS(f)$stand$J else NA })
  cat(sprintf("ln J, long drought u108 %s: %s\n", m, paste(sprintf("%s %+.4f", t, (log(J) - log(J[1])) / 0.025), collapse = ", "))) }
