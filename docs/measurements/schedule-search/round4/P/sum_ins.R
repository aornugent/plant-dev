# The inset pairs against a09's on all ten: decision, C1-C5, worst / rms error, read, T (rows model and real CPU).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
TRAIN <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma")
score <- function(cs, xc, xf) { ref <- refq(cs); qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k)
  ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e; d <- (qc[k] - qf[k]) / e; p <- pilot_of(cs); sh <- alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times)
  coarse <- all(abs(d / (1 - sh)) < 1); err <- if (coarse) ec else ef; sest <- if (coarse) d / (1 - sh) else d * sh / (1 - sh); cr <- crit(err, sest)
  big <- pmax(abs(err), abs(sest)) > 1 / 3; ok3 <- abs(sest[big]) >= abs(err[big]) / 2 & abs(sest[big]) <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  rows <- function(x) run_cost(x$stand$rows, TRUE); use <- if (coarse) xc else xf
  list(coarse = coarse, pass = all(cr), cr = cr, n3 = sprintf("%d/%d", sum(ok3), sum(big)), worst = max(abs(err)), wq = k[which.max(abs(err))], rms = sqrt(mean(err^2)),
       read = median((d / (1 - sh) / ec)[abs(ec) > 0.2]), s = sh, T = rows(xc) + rows(xf) + 2 * rows(use), Tcpu = cpu_of(xc) + cpu_of(xf) + 2 * cpu_of(use), nc = length(xc$node_times), nf = length(xf$node_times)) }
tot <- matrix(0, 2, 4, dimnames = list(c("a09", "ins"), c("T10", "T5", "C10", "C5")))
for (cs in ALL) { a <- score(cs, rd_run("a09", "c", cs), rd_run("a09", "f", cs))
  fc <- file.path(POUT, "runs", sprintf("P_insc_%s.rds", cs)); ff <- file.path(POUT, "runs", sprintf("P_insf_%s.rds", cs)); if (!file.exists(fc) || !file.exists(ff)) { cat(cs, "missing\n"); next }
  yc <- readRDS(fc); yf <- readRDS(ff); if (is.null(yc$stand$elasticity) || is.null(yf$stand$elasticity)) { cat(cs, "incomplete\n"); next }
  b <- score(cs, yc, yf); tr <- cs %in% TRAIN
  tot["a09", ] <- tot["a09", ] + c(a$T, if (tr) a$T else 0, a$Tcpu, if (tr) a$Tcpu else 0); tot["ins", ] <- tot["ins", ] + c(b$T, if (tr) b$T else 0, b$Tcpu, if (tr) b$Tcpu else 0)
  cat(sprintf("%-13s | a09 %s %s worst %.2f rms %.3f read %.2f C3 %s s %.2f T %4.0f cpu %4.0f | inset n %d/%d %s %s worst %.2f (%s) rms %.3f read %.2f C3 %s s %.2f T %4.0f (%+3.0f%%) cpu %4.0f (%+3.0f%%)\n", cs,
    if (a$coarse) "coarse" else "fine  ", if (a$pass) "pass" else "FAIL", a$worst, a$rms, a$read, a$n3, a$s, a$T, a$Tcpu,
    b$nc, b$nf, if (b$coarse) "coarse" else "fine  ", if (b$pass) "pass" else paste("FAIL", paste(names(b$cr)[!b$cr], collapse = "")), b$worst, b$wq, b$rms, b$read, b$n3, b$s, b$T, 100 * (b$T / a$T - 1), b$Tcpu, 100 * (b$Tcpu / a$Tcpu - 1))) }
print(round(tot)); cat(sprintf("T all ten %.0f -> %.0f (%+.1f%%), training five %.0f -> %.0f (%+.1f%%); real CPU %+.1f%% / %+.1f%%\n", tot[1, 1], tot[2, 1], 100 * (tot[2, 1] / tot[1, 1] - 1), tot[1, 2], tot[2, 2], 100 * (tot[2, 2] / tot[1, 2] - 1), 100 * (tot[2, 3] / tot[1, 3] - 1), 100 * (tot[2, 4] / tot[1, 4] - 1)))
