# score_bank.R: B, the ten-case bank, rule N at s = 1.6 and 1. The coarse pair's estimate of the
# committed rung's error, est = (Q_1.6 - Q_1)/(1/s_x - 1), s_x = P_1/P_1.6, scored as H1 scored
# its companion (C1-C5 by crit; read = median est/err over |err| > 0.2), beside E6's pair and
# H1's companion (h1_score_insx.rds).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/score_lib.R")
H1 <- readRDS("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/h1/h1_score_insx.rds")$O
O <- list(); QQ <- list()
for (cs in ALL) { x <- h5_run(sprintf("h5_N16_%s", cs)); c0 <- h5_run(sprintf("h5_N10_%s", cs)); if (is.null(x) || is.null(c0)) { cat(cs, ": missing\n"); next }
  ref <- ref5(cs); p <- pilot_of(cs); k <- Reduce(intersect, list(names(ref), names(quantities(x)), names(quantities(c0)))); e <- eps_vec(k)
  ex <- (quantities(x)[k] - ref[k]) / e; ec <- (quantities(c0)[k] - ref[k]) / e
  sx <- alg$proxy_err(p, sort(c0$node_times)) / alg$proxy_err(p, sort(x$node_times)); est <- (ex - ec) / (1 / sx - 1); cr <- crit(ec, est)
  big <- pmax(abs(ec), abs(est)) > 1 / 3; ok3 <- abs(est) >= abs(ec) / 2 & abs(est) <= 2 * abs(ec) & sign(est) == sign(ec)
  e6c <- ag_run(sprintf("val_ins75_c_%s", cs)); e6f <- ag_run(sprintf("val_ins75_f_%s", cs)); z6 <- score_pair(cs, e6c, e6f, ref); h1 <- H1[H1$case == cs, ]
  j <- abs(ec) > 0.2
  O[[cs]] <- data.frame(case = cs, n_x = length(x$node_times), n_c = length(c0$node_times), n_e6c = length(e6c$node_times), rows_x = rows_of(x), rows_c = rows_of(c0), rows_e6c = rows_of(e6c), rows_e6f = rows_of(e6f),
    cpu_x = cpu_of(x), cpu_c = cpu_of(c0), cpu_e6c = cpu_of(e6c), worst_c = max(abs(ec)), wq = k[which.max(abs(ec))], rms_c = r2(ec), M_c = onM(ec), worst_x = max(abs(ex)), worst_e6c = z6$cworst,
    s_x = sx, worst_est = max(abs(est)), flags = any(abs(est) >= 1), C1 = cr[["C1"]], C2 = cr[["C2"]], C3 = cr[["C3"]], C5 = cr[["C5"]], C3n = sprintf("%d/%d", sum(ok3[big]), sum(big)),
    miss = paste(k[big & !ok3], collapse = ","), pass = all(cr), read = if (any(j)) median((est / ec)[j]) else NA, corr = cor(est, ec), unseen = r2(ec - est), cos = cosv(ex - ec, ec),
    E6_pass = z6$pass, E6_read = z6$read, H1_pass = h1$pass, H1_read = h1$read)
  QQ[[cs]] <- data.frame(case = cs, q = k, cls = cls(k), ec = ec, ex = ex, est = est) }
B <- do.call(rbind, O); rownames(B) <- NULL; Q <- do.call(rbind, QQ); rownames(Q) <- NULL
saveRDS(list(B = B, Q = Q), file.path(H5, "bank_N.rds")); op <- options(width = 250)
print(B[, c("case", "n_x", "n_c", "n_e6c", "rows_x", "rows_c", "rows_e6c", "worst_c", "wq", "rms_c", "M_c", "worst_x", "worst_e6c", "s_x", "worst_est", "flags", "C1", "C2", "C3", "C5", "C3n", "pass", "read", "corr", "unseen", "cos", "E6_pass", "E6_read", "H1_pass", "H1_read")], digits = 3, row.names = FALSE)
for (cs in B$case[B$miss != ""]) cat(cs, "C3 misses:", B$miss[B$case == cs], "\n")
j <- abs(Q$ec) > 0.2
cat(sprintf("\nall: pass %d/%d (E6 %d, H1 %d) | case reads median %.2f [%.2f, %.2f] | pooled read (|err| > 0.2, n %d) %.2f [10-90%%: %.2f, %.2f] | rows N10/E6c %.3f (per case %.2f-%.2f), N16/E6c %.3f | worst N10 > E6c on %d/%d\n",
  sum(B$pass), nrow(B), sum(B$E6_pass), sum(B$H1_pass), median(B$read), min(B$read), max(B$read), sum(j), median(Q$est[j] / Q$ec[j]), quantile(Q$est[j] / Q$ec[j], 0.1), quantile(Q$est[j] / Q$ec[j], 0.9),
  sum(B$rows_c) / sum(B$rows_e6c), min(B$rows_c / B$rows_e6c), max(B$rows_c / B$rows_e6c), sum(B$rows_x) / sum(B$rows_e6c), sum(B$worst_c > B$worst_e6c), nrow(B)))
for (g in c("leaf", "hydraulic", "lnJ", "other")) { m <- j & Q$cls == g; if (any(m)) cat(sprintf("  %-9s n %3d read %.2f [%.2f, %.2f]\n", g, sum(m), median(Q$est[m] / Q$ec[m]), quantile(Q$est[m] / Q$ec[m], 0.1), quantile(Q$est[m] / Q$ec[m], 0.9))) }
