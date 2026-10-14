# U7: the lma x0.9 use pair on episodic's grids against its own reference (u215 -> u429).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
A <- pair("episodic"); a <- quantities(readRDS(file.path(R, "F_ref_l09_u215.rds"))); b <- quantities(readRDS(file.path(R, "F_ref_l09_u429.rds")))
qc <- quantities(readRDS(file.path(R, "F_l09c.rds"))); qf <- quantities(readRDS(file.path(R, "F_l09f.rds")))
k <- Reduce(intersect, list(names(a), names(b), names(qc), A$k)); e <- eps_vec(k); ref <- extrap(a[k], b[k])
ec <- (qc[k] - ref) / e; ef <- (qf[k] - ref) / e; d1 <- (qc[k] - qf[k]) / e; s <- A$s; est1 <- d1 / (1 - s); est0 <- (A$d / (1 - s))[k]
cat(sprintf("reference's own move u215 -> u429 / 3: max %.2f eps (%s)\n", max(abs((b[k] - a[k]) / 3 / e)), k[which.max(abs((b[k] - a[k]) / e))]))
cat(sprintf("use on c: worst %.2f (%s), a_l1 %.2f | its own pair's read d1/(1-s) a_l1 %.2f, median read %.2f | theta0's estimate as its estimate: %s\n",
  max(abs(ec)), k[which.max(abs(ec))], ec["a_l1"], est1["a_l1"], median((est1 / ec)[abs(ec) > 0.2]), paste(names(crit(ec, est0)), as.integer(crit(ec, est0)), collapse = " ")))
cat(sprintf("use on f: worst %.2f (%s) | theta0's fine estimate d0 s/(1-s): %s | own pair's: %s\n", max(abs(ef)), k[which.max(abs(ef))],
  paste(names(crit(ef, est0 * s)), as.integer(crit(ef, est0 * s)), collapse = " "), paste(as.integer(crit(ef, est1 * s)), collapse = "")))
o <- order(-abs(ec))[1:6]; print(data.frame(q = k[o], err_c = round(ec[o], 2), est1 = round(est1[o], 2), est0 = round(est0[o], 2), err_f = round(ef[o], 2)), row.names = FALSE)
