# Inset pairs: error, estimate and read per quantity over eps/5; the shared part (both runs' error along in10's direction M, dry).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
for (cs in commandArgs(TRUE)) { ref <- refq(cs); ld <- function(s) readRDS(file.path(POUT, "runs", sprintf("P_ins%s_%s.rds", s, cs))); xc <- ld("c"); xf <- ld("f")
  qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k); ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e
  p <- pilot_of(cs); s <- alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times); est <- (ec - ef) / (1 - s)
  # the error the pair implies is extrapolated: x = c - est; its distance from the reference is the unread (shared) part
  un <- ec - est; o <- order(-abs(ec))[1:8]
  cat(sprintf("%s: s %.2f | c rms %.3f f rms %.3f | unread (c - est) rms %.3f worst %.2f (%s) | corr(est, c err) %.2f\n", cs, s, sqrt(mean(ec^2)), sqrt(mean(ef^2)), sqrt(mean(un^2)), max(abs(un)), k[which.max(abs(un))], cor(est, ec)))
  print(round(data.frame(c_err = ec[o], f_err = ef[o], est = est[o], read = est[o] / ec[o], unread = un[o], f_over_c = ef[o] / ec[o]), 2))
  if (cs == "dry") { B <- pair(cs); q <- quantities(readRDS(file.path(POUT, "runs", "P_in10_dry.rds"))); M <- (q[k] - B$qc[k]) / e; pr <- function(v) -sum(v * M) / sum(M^2)
    cat(sprintf("   on -M: c %.2f f %.2f est %.2f unread %.2f\n", pr(ec), pr(ef), pr(est), pr(un))) } }
