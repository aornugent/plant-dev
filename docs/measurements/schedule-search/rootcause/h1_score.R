# h1_score.R: H1 scored. The E6 committed run (val_ins75_c) with its error estimated by the
# coarse companion, err_est = (Q_coarse - Q_committed)/(1/s_c - 1), s_c = proxy(committed)/
# proxy(coarse), beside E6's own finer check (score_pair). References on lib19 as E6's.
# TAG=insx12 scores the 12-day-inset diagnostic companions instead.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R"))
H1 <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/h1"
TAG <- Sys.getenv("TAG", "insx")
HYD <- c("a_l1", "root_P50", "omega", "root_c", "stem_c", "storage_relaxation_offset")
LEAF <- c("a", "curv_fact_elec_trans", "k_I", "jmax_25", "lma", "vcmax_25", "R_d_25")
cls <- function(k) ifelse(k == "lnJ", "lnJ", ifelse(k %in% HYD, "hydraulic", ifelse(k %in% LEAF, "leaf", "other")))
rows <- function(x) run_cost(x$stand$rows, TRUE)
c3 <- function(err, sest) { big <- pmax(abs(err), abs(sest)) > 1 / 3
  ok <- abs(sest) >= abs(err) / 2 & abs(sest) <= 2 * abs(err) & sign(sest) == sign(err); list(big = big, ok = ok) }
reads <- function(est, ec, k) { j <- abs(ec) > 0.2; r <- est / ec
  sapply(c(all = "all", leaf = "leaf", hydraulic = "hydraulic", lnJ = "lnJ", other = "other"), function(g) { m <- j & (g == "all" | cls(k) == g); if (any(m)) median(r[m]) else NA }) }
out <- list(); RD <- list(); QQ <- list()
for (cs in ALL) { fx <- file.path(H1, "runs", sprintf("val_%s_x_%s.rds", TAG, cs)); if (!file.exists(fx)) { cat(cs, ": companion missing\n"); next }
  xx <- readRDS(fx); if (is.null(xx$stand$elasticity)) { cat(cs, ": companion has no gradient\n"); next }
  xc <- ag_run(sprintf("val_ins75_c_%s", cs)); xf <- ag_run(sprintf("val_ins75_f_%s", cs)); ref <- refq(cs)
  z6 <- score_pair(cs, xc, xf, ref)
  qc <- quantities(xc); qf <- quantities(xf); qx <- quantities(xx); k <- Reduce(intersect, list(names(ref), names(qc), names(qf), names(qx))); stopifnot(identical(k, z6$k))
  e <- eps_vec(k); ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e; ex <- (qx[k] - ref[k]) / e
  p <- pilot_of(cs); pc <- alg$proxy_err(p, xc$node_times); px <- alg$proxy_err(p, xx$node_times); s_c <- pc / px
  est <- (ex - ec) / (1 / s_c - 1)                         # the companion's estimate of the committed run's error
  est6 <- (ec - ef) / (1 - z6$s)                           # E6's finer check's estimate of the same error
  # The companion alone, against the committed run's true error (C5: every |estimate| <= eps).
  cr <- crit(ec, est); a3 <- c3(ec, est); b3 <- c3(ec, est6)
  # The protocol: commit the committed run if every |estimate| < eps; else the finer run follows
  # and the case is decided and scored as E6's pair.
  ok <- all(abs(est) < 1)
  pass <- if (ok) all(cr) else z6$pass
  Tr <- rows(xc) + rows(xx) + if (ok) 2 * rows(xc) else rows(xf) + 2 * rows(if (z6$coarse) xc else xf)
  Tcpu <- cpu_of(xc) + cpu_of(xx) + if (ok) 2 * cpu_of(xc) else cpu_of(xf) + 2 * cpu_of(if (z6$coarse) xc else xf)
  # Measured shrink coarse -> committed (least squares), per class, against s_c.
  shr <- function(m) sum(ec[m] * ex[m]) / sum(ex[m]^2)
  out[[cs]] <- data.frame(case = cs, n_c = length(xc$node_times), n_x = length(xx$node_times), n_f = length(xf$node_times),
    s_c = s_c, s_f = z6$s, meas_s = shr(rep(TRUE, length(k))), meas_s_hyd = shr(cls(k) == "hydraulic"), meas_s_leaf = shr(cls(k) == "leaf"),
    worst_c = max(abs(ec)), wq = k[which.max(abs(ec))], worst_x = max(abs(ex)), worst_est = max(abs(est)), commit = if (ok) "c" else if (z6$coarse) "c (after f)" else "f",
    C1 = cr[["C1"]], C2 = cr[["C2"]], C3 = cr[["C3"]], C5 = cr[["C5"]], C3n = sprintf("%d/%d", sum(a3$ok[a3$big]), sum(a3$big)), miss = paste(k[a3$big & !a3$ok], collapse = ","),
    pass = pass, read = median((est / ec)[abs(ec) > 0.2]), corr = cor(est, ec), rms_ratio = sqrt(mean(est^2)) / sqrt(mean(ec^2)),
    E6_pass = z6$pass, E6_commit = if (z6$coarse) "c" else "f", E6_C3n = z6$n3, E6_read = z6$read, E6_corr = z6$corr, E6_rms_ratio = sqrt(mean(est6^2)) / sqrt(mean(ec^2)),
    E6_C3c = sprintf("%d/%d", sum(b3$ok[b3$big]), sum(b3$big)),
    rows_c = rows(xc), rows_x = rows(xx), rows_f = rows(xf), cpu_c = cpu_of(xc), cpu_x = cpu_of(xx), cpu_f = cpu_of(xf), T = Tr, Tcpu = Tcpu, T6 = z6$T, T6cpu = z6$Tcpu)
  RD[[cs]] <- rbind(H1 = reads(est, ec, k), E6 = reads(est6, ec, k))
  QQ[[cs]] <- data.frame(case = cs, q = k, cls = cls(k), ec = ec, ex = ex, ef = ef, est = est, est6 = est6) }
O <- do.call(rbind, out); rownames(O) <- NULL; Q <- do.call(rbind, QQ); rownames(Q) <- NULL
saveRDS(list(O = O, RD = RD, Q = Q), file.path(H1, sprintf("h1_score_%s.rds", TAG)))
op <- options(width = 250)
cat("== per case: the companion (H1) beside E6's finer check\n")
print(O[, c("case", "n_c", "n_x", "n_f", "s_c", "s_f", "meas_s", "meas_s_hyd", "meas_s_leaf", "worst_c", "wq", "worst_est", "commit", "C1", "C2", "C3", "C5", "C3n", "pass", "read", "corr", "rms_ratio", "miss")], digits = 3)
print(O[, c("case", "E6_commit", "E6_pass", "E6_C3n", "E6_C3c", "E6_read", "E6_corr", "E6_rms_ratio", "rows_c", "rows_x", "rows_f", "cpu_c", "cpu_x", "cpu_f", "T", "T6", "Tcpu", "T6cpu")], digits = 3)
cat("\n== reads (median est/err over |err| > 0.2) by class: H1 row, then E6 row\n")
for (cs in names(RD)) { cat(sprintf("%-13s", cs)); print(round(RD[[cs]], 2)) }
cat("\n== pooled reads by class (median over all cases' quantities with |err| > 0.2), and n\n")
j <- abs(Q$ec) > 0.2
for (g in c("all", "leaf", "hydraulic", "lnJ", "other")) { m <- j & (g == "all" | Q$cls == g)
  cat(sprintf("  %-9s n %3d | H1 %.2f [%.2f, %.2f] | E6 %.2f [%.2f, %.2f]\n", g, sum(m), median(Q$est[m] / Q$ec[m]), quantile(Q$est[m] / Q$ec[m], 0.1), quantile(Q$est[m] / Q$ec[m], 0.9),
    median(Q$est6[m] / Q$ec[m]), quantile(Q$est6[m] / Q$ec[m], 0.1), quantile(Q$est6[m] / Q$ec[m], 0.9))) }
cat("\n== hydraulic quantities with |err| > 0.2, per case: err, H1 est, E6 est\n")
h <- Q[Q$cls == "hydraulic" & abs(Q$ec) > 0.2, ]; print(transform(h[, c("case", "q", "ec", "est", "est6")], r_H1 = est / ec, r_E6 = est6 / ec), digits = 2)
cat(sprintf("\n== totals: pass %d/10 (E6 %d/10) | T rows %.0f (E6 %.0f, %+.1f%%) | T cpu %.0f (E6 %.0f, %+.1f%%)\n", sum(O$pass), sum(O$E6_pass), sum(O$T), sum(O$T6), 100 * (sum(O$T) / sum(O$T6) - 1),
  sum(O$Tcpu), sum(O$T6cpu), 100 * (sum(O$Tcpu) / sum(O$T6cpu) - 1)))
cat(sprintf("   companion cost / committed: rows %.3f (per case %.2f-%.2f), cpu %.3f (%.2f-%.2f); nodes %.3f | finer check rows %.3f, cpu %.3f\n",
  sum(O$rows_x) / sum(O$rows_c), min(O$rows_x / O$rows_c), max(O$rows_x / O$rows_c), sum(O$cpu_x) / sum(O$cpu_c), min(O$cpu_x / O$cpu_c), max(O$cpu_x / O$cpu_c),
  sum(O$n_x) / sum(O$n_c), sum(O$rows_f) / sum(O$rows_c), sum(O$cpu_f) / sum(O$cpu_c)))
cat(sprintf("   median read: H1 %.2f, E6 %.2f (per-case medians: H1 %.2f-%.2f, E6 %.2f-%.2f)\n", median(O$read), median(O$E6_read), min(O$read), max(O$read), min(O$E6_read), max(O$E6_read)))
