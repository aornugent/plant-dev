# score_w.R CASE...: W, the s = 2.0 rung. The 2.0 / 1.6 / 1 ladder (score_ladder.R RUNGS=20,16,10)
# plus the wide pair (2.0, 1) read against the s = 1 rung's true error:
# est = (Q_2 - Q_1)/(P_2/P_1 - 1), and the widest open interval per rung (d).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/score_lib.R")
for (cs in commandArgs(TRUE)) { r <- lapply(c(s20 = "N20", s16 = "N16", s10 = "N10"), function(k) h5_run(sprintf("h5_%s_%s", k, cs))); if (any(sapply(r, is.null))) { cat(cs, ": missing\n"); next }
  ref <- ref5(cs); p <- pilot_of(cs); P <- sapply(r, function(z) alg$proxy_err(p, sort(z$node_times)))
  k <- Reduce(intersect, c(list(names(ref)), lapply(r, function(z) names(quantities(z))))); e <- eps_vec(k)
  E <- lapply(r, function(z) (quantities(z)[k] - ref[k]) / e); est <- (E$s20 - E$s10) / (P[["s20"]] / P[["s10"]] - 1); ec <- E$s10
  wid <- sapply(r, function(z) { S <- sort(z$node_times); d <- diff(S) * 365; m <- (head(S, -1) + S[-1]) / 2; op <- p$shut(m) < 0.5; c(lt20 = max(d[op & m < 20]), b20_25 = max(d[op & m >= 20 & m < 25])) })
  cr <- crit(ec, est); j <- abs(ec) > 0.2
  cat(sprintf("%-13s wide pair (2.0, 1) on s = 1's error: shrink P1/P2 %.3f | read %.2f corr %.2f rms ratio %.2f | C1 %s C2 %s C3 %s C5 %s | unseen rms %.3f | worst s=2 %.2f s=1.6 %.2f s=1 %.2f | widest interval b<20: %s d; 20-25: %s d | rows %s | steps %s\n",
    cs, P[["s10"]] / P[["s20"]], median((est / ec)[j]), cor(est, ec), r2(est) / r2(ec), cr[["C1"]], cr[["C2"]], cr[["C3"]], cr[["C5"]], r2(ec - est), max(abs(E$s20)), max(abs(E$s16)), max(abs(E$s10)),
    paste(round(wid[1, ]), collapse = "/"), paste(round(wid[2, ]), collapse = "/"), paste(round(sapply(r, rows_of)), collapse = "/"), paste(sapply(r, steps_of), collapse = "/"))) }
