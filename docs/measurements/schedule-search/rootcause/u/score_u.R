# score_u.R [RULE] [CASE...]: per case, a three-rung ladder (RULE16 / RULE10 / RULE06, default
# U) beside E6's committed and check runs:
#  - error per rung (worst, rms, along M), rows against E6 committed and check;
#  - the coarse pair's estimate d1/(1/s_x - 1) and the fine pair's d2/(1 - s_f) of the
#    committed rung's error: read, C1-C5 on the real runs, what each leaves (err_c - est),
#    and the part of err_c outside span(d1, d2);
#  - STRESS: the protocol (commit the committed rung when every |est| < 1, else the fine rung
#    with the fine pair's estimate of it) decided on perturbed values, judged against the
#    truth; coord = miss N(0, 0.025^2) shared by a case's runs + N(0, 0.04^2) per run;
#    jit = N(0, 0.020^2) per quantity + 0.09 z along M per run. E6's pair on the same draws;
#  - rows at E6 committed's worst and rms error, log-log along the ladder's rungs;
#  - T in the rows model for each protocol on the real runs (runs made + 2 x the answer).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/u/lib.R")
a <- commandArgs(TRUE); RULE <- if (length(a) && !(a[1] %in% ALL)) a[1] else "U"; CS <- setdiff(a, RULE); if (!length(CS)) CS <- ALL
ND <- as.integer(Sys.getenv("ND", "1000"))
at <- function(rows, y, target) { o <- order(rows); x <- log(rows[o]); y <- log(y[o])
  for (i in seq_along(x)[-1]) if ((y[i - 1] - log(target)) * (y[i] - log(target)) <= 0) return(exp(x[i - 1] + (log(target) - y[i - 1]) / (y[i] - y[i - 1]) * (x[i] - x[i - 1])))
  NA }
proto <- function(vc, vf, est_c, ec, ef, sf) if (all(abs(est_c) < 1)) all(crit(ec, est_c)) else all(crit(ef, (vc - vf) * sf / (1 - sf)))
OUT <- list(); STR <- list()
for (cs in CS) { x <- h5_run(sprintf("h5_%s16_%s", RULE, cs)); c0 <- h5_run(sprintf("h5_%s10_%s", RULE, cs)); f <- h5_run(sprintf("h5_%s06_%s", RULE, cs))
  if (is.null(x) || is.null(c0) || is.null(f)) { cat(cs, ": rung missing\n"); next }
  e6c <- ag_run(sprintf("val_ins75_c_%s", cs)); e6f <- ag_run(sprintf("val_ins75_f_%s", cs))
  ref <- ref5(cs); p <- pilot_of(cs); P <- function(z) alg$proxy_err(p, sort(z$node_times))
  k <- Reduce(intersect, lapply(list(x, c0, f, e6c, e6f), function(z) names(quantities(z))), names(ref)); e <- eps_vec(k)
  E <- function(z) (quantities(z)[k] - ref[k]) / e
  ex <- E(x); ec <- E(c0); ef <- E(f); g6c <- E(e6c); g6f <- E(e6f)
  sx <- P(c0) / P(x); sf <- P(f) / P(c0); s6 <- P(e6f) / P(e6c)
  d1 <- ex - ec; d2 <- ec - ef; estx <- d1 / (1 / sx - 1); estf <- d2 / (1 - sf); est6 <- (g6c - g6f) / (1 - s6)
  B <- cbind(d1, d2); outside <- ec - B %*% qr.solve(B, ec)
  rd <- function(est) { m <- abs(ec) > 0.2; if (any(m)) median((est / ec)[m]) else NA }
  crx <- crit(ec, estx); crf <- crit(ec, estf)
  cost <- function(z) run_cost(z$stand$rows, TRUE)
  Tx <- if (all(abs(estx) < 1)) cost(x) + 3 * cost(c0) else cost(x) + cost(c0) + 3 * cost(f)
  Tf <- if (all(abs(estf) < 1)) 3 * cost(c0) + cost(f) else cost(c0) + 3 * cost(f)
  T6 <- if (all(abs(est6) < 1)) 3 * cost(e6c) + cost(e6f) else cost(e6c) + 3 * cost(e6f)
  rows <- sapply(list(x, c0, f), rows_of); wst <- sapply(list(ex, ec, ef), function(v) max(abs(v))); rmss <- sapply(list(ex, ec, ef), r2)
  M <- M_unit[k]; M[is.na(M)] <- 0; nq <- length(k)
  st <- list(); for (nz in c("coord", "jit")) { px <- pf <- p6 <- logical(ND); fc <- matrix(FALSE, ND, 4, dimnames = list(NULL, c("C1", "C2", "C3", "C5")))
    for (d in seq_len(ND)) { set.seed(1e6 * match(cs, ALL) + d + if (nz == "jit") 5e5 else 0)
      run <- function() if (nz == "coord") rnorm(nq, 0, 0.04) else rnorm(nq, 0, 0.020) + 0.09 * rnorm(1) * M
      m <- if (nz == "coord") rnorm(nq, 0, 0.025) else 0
      vx <- ex + m + run(); vc <- ec + m + run(); vf <- ef + m + run(); w6c <- g6c + m + run(); w6f <- g6f + m + run()
      ex_ <- (vx - vc) / (1 / sx - 1); px[d] <- proto(vc, vf, ex_, ec, ef, sf)
      if (all(abs(ex_) < 1)) fc[d, ] <- !crit(ec, ex_) else fc[d, ] <- !crit(ef, (vc - vf) * sf / (1 - sf))
      pf[d] <- proto(vc, vf, (vc - vf) / (1 - sf), ec, ef, sf); p6[d] <- proto(w6c, w6f, (w6c - w6f) / (1 - s6), g6c, g6f, s6) }
    st[[nz]] <- c(x = mean(px), f = mean(pf), e6 = mean(p6), colMeans(fc)) }
  STR[[cs]] <- st
  OUT[[cs]] <- data.frame(case = cs, rule = RULE, n_x = length(x$node_times), n_c = length(c0$node_times), n_f = length(f$node_times), n_e6c = length(e6c$node_times), n_e6f = length(e6f$node_times),
    rows_x = rows[1], rows_c = rows[2], rows_f = rows[3], rows_e6c = rows_of(e6c), rows_e6f = rows_of(e6f), rc_e6c = rows[2] / rows_of(e6c), rc_e6f = rows[2] / rows_of(e6f), rf_e6f = rows[3] / rows_of(e6f),
    worst_x = wst[1], worst_c = wst[2], worst_f = wst[3], wq_c = k[which.max(abs(ec))], rms_x = rmss[1], rms_c = rmss[2], rms_f = rmss[3], M_x = onM(ex), M_c = onM(ec), M_f = onM(ef),
    worst_e6c = max(abs(g6c)), rms_e6c = r2(g6c), M_e6c = onM(g6c), worst_e6f = max(abs(g6f)),
    at_worst = at(rows, wst, max(abs(g6c))) / rows_of(e6c), at_rms = at(rows, rmss, r2(g6c)) / rows_of(e6c),
    s_x = sx, s_f = sf, cos12 = cosv(d1, d2), M_d1 = onM(d1), M_d2 = onM(d2),
    read_x = rd(estx), read_f = rd(estf), read_6 = median((est6 / g6c)[abs(g6c) > 0.2]), corr_x = cor(estx, ec), corr_f = cor(estf, ec),
    C1 = crx[["C1"]], C2x = crx[["C2"]], C3x = crx[["C3"]], C5x = crx[["C5"]], C2f = crf[["C2"]], C3f = crf[["C3"]], C5f = crf[["C5"]], pass_x = all(crx), pass_f = all(crf),
    proto_x = proto(ec, ef, estx, ec, ef, sf), proto_f = proto(ec, ef, estf, ec, ef, sf), flag_x = any(abs(estx) >= 1), flag_f = any(abs(estf) >= 1),
    unseen_x = r2(ec - estx), unseen_f = r2(ec - estf), outside = r2(outside), outside_max = max(abs(outside)),
    T_x = Tx, T_f = Tf, T_e6 = T6,
    st_x = st$coord[["x"]], st_f = st$coord[["f"]], st_e6 = st$coord[["e6"]], stj_x = st$jit[["x"]], stj_f = st$jit[["f"]], stj_e6 = st$jit[["e6"]],
    stC1 = st$coord[["C1"]], stC2 = st$coord[["C2"]], stC3 = st$coord[["C3"]], stC5 = st$coord[["C5"]]) }
O <- do.call(rbind, OUT); rownames(O) <- NULL
saveRDS(list(O = O, STR = STR), file.path(UOUT, sprintf("score_%s_%s.rds", RULE, if (length(CS) == length(ALL)) "all" else paste(CS, collapse = "+"))))
op <- options(width = 250)
print(O[, c("case", "n_c", "n_e6c", "rows_c", "rows_e6c", "rc_e6c", "rc_e6f", "worst_x", "worst_c", "worst_f", "wq_c", "rms_c", "M_c", "worst_e6c", "rms_e6c", "M_e6c", "at_worst", "at_rms")], digits = 3, row.names = FALSE)
print(O[, c("case", "cos12", "read_x", "read_f", "read_6", "corr_x", "corr_f", "pass_x", "pass_f", "proto_x", "proto_f", "flag_x", "flag_f", "unseen_x", "unseen_f", "outside", "outside_max")], digits = 3, row.names = FALSE)
print(O[, c("case", "T_x", "T_f", "T_e6", "st_x", "st_f", "st_e6", "stj_x", "stj_f", "stj_e6", "stC1", "stC2", "stC3", "stC5")], digits = 3, row.names = FALSE)
cat(sprintf("\nall %d: rows c / E6 c %.3f (summed), / E6 f %.3f | real pass coarse %d, fine %d (protocol %d / %d) | STRESS coord: coarse %.3f fine %.3f E6 %.3f of case-draws | jit: %.3f %.3f %.3f | T_x / T_e6 %.3f, T_f / T_e6 %.3f\n",
  nrow(O), sum(O$rows_c) / sum(O$rows_e6c), sum(O$rows_c) / sum(O$rows_e6f), sum(O$pass_x), sum(O$pass_f), sum(O$proto_x), sum(O$proto_f), mean(O$st_x), mean(O$st_f), mean(O$st_e6),
  mean(O$stj_x), mean(O$stj_f), mean(O$stj_e6), sum(O$T_x) / sum(O$T_e6), sum(O$T_f) / sum(O$T_e6)))
