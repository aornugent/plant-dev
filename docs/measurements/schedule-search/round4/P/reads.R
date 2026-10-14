# reads.R TAG CASE...: per quantity with |c error| > eps/5, the shrink f/c against s and the read, split into
# leaf (photosynthesis, allocation) and hydraulic quantities.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
HYD <- c("root_P50", "storage_relaxation_offset", "stem_c", "stem_P50", "root_c", "omega", "K_s", "TF24_cost_scale", "a_dG1", "a_dG2", "k_s", "rho")
a <- commandArgs(TRUE); tag <- a[1]
for (cs in a[-1]) { ref <- refq(cs); ld <- function(s) readRDS(file.path(POUT, "runs", sprintf("P_%s%s_%s.rds", tag, s, cs))); xc <- ld("c"); xf <- ld("f")
  qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k); ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e
  p <- pilot_of(cs); s <- alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times); est <- (ec - ef) / (1 - s); m <- abs(ec) > 0.2
  for (g in c("leaf", "hydraulic")) { z <- m & ((k %in% HYD) == (g == "hydraulic")); if (!any(z)) next
    cat(sprintf("%-13s %-9s s %.2f: n %d, median f/c %.2f, median read %.2f | %s\n", cs, g, s, sum(z), median(ef[z] / ec[z]), median(est[z] / ec[z]),
      paste(sprintf("%s %.2f/%.2f", k[z], ec[z], est[z] / ec[z]), collapse = ", "))) } }
