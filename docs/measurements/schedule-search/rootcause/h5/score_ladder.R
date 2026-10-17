# score_ladder.R RULE CASE...: an H5 ladder (runs h5_<RULE>16 / <RULE>10 / <RULE>06, s = 1.6,
# 1, 1/1.6) scored per case:
#  - errors against the lib19-class reference (eps); moves d1 = x - c, d2 = c - f;
#  - order: pooled (projected d1 on d2) and per quantity, read against the proxy's
#    shrink (s_x = P_c/P_x, s_f = P_f/P_c; order q solves (Px^q - Pc^q)/(Pc^q - Pf^q) =
#    ratio, p = 2q) and nominally (log ratio / log 1.6);
#  - the two pairs' estimates of the committed run's error: coarse d1/(1/s_x - 1), fine
#    d2/(1 - s_f); reads est/err, C1-C5 (crit) for each, E6's decision (score_pair);
#  - what neither pair sees: err_c - est (fixed strips, reference, higher order);
#  - rows, CPU, steps per rung beside E6's committed and check runs.
# JIT (env, a run name) gives the jitter move used for the noise floor.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/score_lib.R")
a <- commandArgs(TRUE); RULE <- a[1]; CS <- a[-1]
qord <- function(Px, Pc, Pf, rho) { if (!is.finite(rho) || rho <= 0) return(NA); f <- function(q) log((Px^q - Pc^q) / (Pc^q - Pf^q)) - log(rho)
  lo <- 0.05; hi <- 4; if (f(lo) * f(hi) > 0) return(if (f(hi) < 0) 2 * hi else 2 * lo); 2 * uniroot(f, c(lo, hi))$root }
JIT <- Sys.getenv("JIT"); jit <- if (nzchar(JIT)) { j <- h5_run(JIT); jc <- h5_run(sub("@jit", "", JIT)); if (!is.null(j) && !is.null(jc)) mv(j, jc) }
OUT <- list(); QQ <- list()
RG <- strsplit(Sys.getenv("RUNGS", "16,10,06"), ",")[[1]]   # coarse, committed, fine rung labels
for (cs in CS) { x <- h5_run(sprintf("h5_%s%s_%s", RULE, RG[1], cs)); c0 <- h5_run(sprintf("h5_%s%s_%s", RULE, RG[2], cs)); f <- h5_run(sprintf("h5_%s%s_%s", RULE, RG[3], cs))
  if (is.null(c0)) { cat(cs, ": committed rung missing\n"); next }
  ref <- ref5(cs); p <- pilot_of(cs); P <- function(z) alg$proxy_err(p, sort(z$node_times))
  k <- names(ref); for (z in list(x, c0, f)) if (!is.null(z)) k <- intersect(k, names(quantities(z))); e <- eps_vec(k)
  E <- function(z) if (is.null(z)) NULL else ((quantities(z)[k] - ref[k]) / e)
  ex <- E(x); ec <- E(c0); ef <- E(f); e6c <- ag_run(sprintf("val_ins75_c_%s", cs)); e6f <- ag_run(sprintf("val_ins75_f_%s", cs)); z6 <- score_pair(cs, e6c, e6f, ref)
  o <- data.frame(case = cs, rule = paste0(RULE, ":", paste(RG, collapse = "/")), n_x = if (!is.null(x)) length(x$node_times) else NA, n_c = length(c0$node_times), n_f = if (!is.null(f)) length(f$node_times) else NA,
    n_e6c = length(e6c$node_times), n_e6f = length(e6f$node_times), worst_c = max(abs(ec)), wq = k[which.max(abs(ec))], rms_c = r2(ec), M_c = onM(ec),
    worst_x = if (!is.null(ex)) max(abs(ex)) else NA, worst_f = if (!is.null(ef)) max(abs(ef)) else NA, worst_e6c = z6$cworst, rms_e6c = z6$crms,
    rows_x = if (!is.null(x)) rows_of(x) else NA, rows_c = rows_of(c0), rows_f = if (!is.null(f)) rows_of(f) else NA, rows_e6c = rows_of(e6c), rows_e6f = rows_of(e6f),
    cpu_x = if (!is.null(x)) cpu_of(x) else NA, cpu_c = cpu_of(c0), cpu_f = if (!is.null(f)) cpu_of(f) else NA, cpu_e6c = cpu_of(e6c), cpu_e6f = cpu_of(e6f),
    steps_c = steps_of(c0), steps_e6c = steps_of(e6c), E6_pass = z6$pass, E6_read = z6$read)
  q <- data.frame(case = cs, q = k, cls = cls(k), ec = ec, ex = if (!is.null(ex)) ex else NA, ef = if (!is.null(ef)) ef else NA, e6c = z6$ec[k])
  if (!is.null(x) && !is.null(f)) {
    Px <- P(x); Pc <- P(c0); Pf <- P(f); sx <- Pc / Px; sf <- Pf / Pc; law <- (1 / sx - 1) / (1 - sf)
    d1 <- ex - ec; d2 <- ec - ef; rho <- proj(d1, d2); estx <- d1 / (1 / sx - 1); estf <- d2 / (1 - sf)
    sig <- if (!is.null(jit)) r2(jit[k]) / sqrt(2) else 0.024           # one run's jitter, rms
    big <- abs(d1) > 0.1 & abs(d2) > 0.05                                  # moves above ~2-3x the difference jitter
    qo <- sapply(seq_along(k), function(i) if (big[i]) qord(Px, Pc, Pf, d1[i] / d2[i]) else NA)
    crx <- crit(ec, estx); crf <- crit(ec, estf)
    c3n <- function(est) { b <- pmax(abs(ec), abs(est)) > 1 / 3; ok <- abs(est) >= abs(ec) / 2 & abs(est) <= 2 * abs(ec) & sign(est) == sign(ec); sprintf("%d/%d", sum(ok[b]), sum(b)) }
    rd <- function(est, m = abs(ec) > 0.2) if (any(m)) median((est / ec)[m]) else NA
    o <- cbind(o, data.frame(s_x = sx, s_f = sf, law = law, rho = rho, meas_law = rho / law, p_pool = qord(Px, Pc, Pf, rho), p_nom = log(rho) / log(1.6),
      cos12 = cosv(d1, d2), rms_d1 = r2(d1), rms_d2 = r2(d2), M_d1 = onM(d1), M_d2 = onM(d2), n_big = sum(big),
      p_med = median(qo, na.rm = TRUE), p_min = suppressWarnings(min(qo, na.rm = TRUE)), p_max = suppressWarnings(max(qo, na.rm = TRUE)),
      p_minq = if (any(big)) k[big][which.min(qo[big])] else NA, p_maxq = if (any(big)) k[big][which.max(qo[big])] else NA,
      read_x = rd(estx), read_f = rd(estf), read_x_hyd = rd(estx, abs(ec) > 0.2 & cls(k) == "hydraulic"), read_f_hyd = rd(estf, abs(ec) > 0.2 & cls(k) == "hydraulic"),
      corr_x = cor(estx, ec), corr_f = cor(estf, ec), rmsr_x = r2(estx) / r2(ec), rmsr_f = r2(estf) / r2(ec),
      C1 = crx[["C1"]], C2x = crx[["C2"]], C3x = crx[["C3"]], C5x = crx[["C5"]], C3nx = c3n(estx), C2f = crf[["C2"]], C3f = crf[["C3"]], C5f = crf[["C5"]], C3nf = c3n(estf),
      pass_x = all(crx), pass_f = all(crf),
      proto_x = if (all(abs(estx) < 1)) all(crx) else all(crit(ef, d2 * sf / (1 - sf))), proto_x_commit = if (all(abs(estx) < 1)) "c" else "f",
      proto_f = if (all(abs(estf) < 1)) all(crf) else all(crit(ef, d2 * sf / (1 - sf))), proto_f_commit = if (all(abs(estf) < 1)) "c" else "f", unseen_x = r2(ec - estx), unseen_f = r2(ec - estf), unseen_x_max = max(abs(ec - estx)), unseen_f_max = max(abs(ec - estf)),
      noise_x = sig * sqrt(2) / (1 / sx - 1), noise_f = sig * sqrt(2) / (1 - sf), noise_c = sig))
    q <- cbind(q, data.frame(d1 = d1, d2 = d2, estx = estx, estf = estf, p = qo)) }
  OUT[[cs]] <- o; QQ[[cs]] <- q }
O <- do.call(rbind, lapply(OUT, function(o) o[, intersect(names(OUT[[1]]), names(o))])); rownames(O) <- NULL
saveRDS(list(O = OUT, Q = QQ, jit = jit), file.path(H5, sprintf("ladder_%s%s_%s.rds", RULE, if (Sys.getenv("RUNGS") == "") "" else paste0("_", paste(RG, collapse = "-")), paste(CS, collapse = "+"))))
op <- options(width = 250)
for (o in OUT) { cat(sprintf("\n== %s (%s): nodes x/c/f %s/%d/%s (E6 c/f %d/%d) | rows %s/%.0f/%s (E6 %.0f/%.0f) | cpu %s/%.0f/%s (E6 %.0f/%.0f)\n", o$case, o$rule, o$n_x, o$n_c, o$n_f, o$n_e6c, o$n_e6f,
    format(round(o$rows_x)), o$rows_c, format(round(o$rows_f)), o$rows_e6c, o$rows_e6f, format(round(o$cpu_x)), o$cpu_c, format(round(o$cpu_f)), o$cpu_e6c, o$cpu_e6f))
  cat(sprintf("   committed err: worst %.2f (%s) rms %.3f M %+.2f | x worst %.2f, f worst %.2f | E6 c worst %.2f rms %.3f\n", o$worst_c, o$wq, o$rms_c, o$M_c, o$worst_x, o$worst_f, o$worst_e6c, o$rms_e6c))
  if (!is.null(o$rho)) {
    cat(sprintf("   order: s_x %.3f s_f %.3f law d1/d2 %.2f | measured %.2f (meas/law %.2f) cos %.2f | p pooled %.2f (nominal %.2f) | per quantity (n %d with |d1|>0.1,|d2|>0.05): median %.2f, min %.2f (%s), max %.2f (%s) | rms d1 %.3f d2 %.3f, M %+.2f %+.2f\n",
      o$s_x, o$s_f, o$law, o$rho, o$meas_law, o$cos12, o$p_pool, o$p_nom, o$n_big, o$p_med, o$p_min, o$p_minq, o$p_max, o$p_maxq, o$rms_d1, o$rms_d2, o$M_d1, o$M_d2))
    cat(sprintf("   coarse pair: read %.2f (hyd %.2f) corr %.2f rms ratio %.2f | C1 %s C2 %s C3 %s (%s) C5 %s | unseen rms %.3f max %.2f | est noise %.3f | protocol: commit %s, pass %s\n", o$read_x, o$read_x_hyd, o$corr_x, o$rmsr_x, o$C1, o$C2x, o$C3x, o$C3nx, o$C5x, o$unseen_x, o$unseen_x_max, o$noise_x, o$proto_x_commit, o$proto_x))
    cat(sprintf("   fine pair:   read %.2f (hyd %.2f) corr %.2f rms ratio %.2f | C1 %s C2 %s C3 %s (%s) C5 %s | unseen rms %.3f max %.2f | est noise %.3f | protocol: commit %s, pass %s | E6 pass %s read %.2f\n", o$read_f, o$read_f_hyd, o$corr_f, o$rmsr_f, o$C1, o$C2f, o$C3f, o$C3nf, o$C5f, o$unseen_f, o$unseen_f_max, o$noise_f, o$proto_f_commit, o$proto_f, o$E6_pass, o$E6_read))
    q <- QQ[[o$case]]; j <- abs(q$ec) > 0.2 | abs(q$estx) > 0.2 | abs(q$estf) > 0.2
    print(transform(q[j, c("q", "ec", "ex", "ef", "d1", "d2", "p", "estx", "estf", "e6c")], rx = round(estx / ec, 2), rf = round(estf / ec, 2)), digits = 2, row.names = FALSE) } }
