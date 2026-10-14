# tol.R: what the tolerance (1e-4 -> 3e-4) moves in each run of a pair, on the same
# schedules, against the edge direction M (dry's in10 move, unit) and the run's own error.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
M <- { p <- quantities(ag_run("P_in10_dry")); b <- quantities(rd_run("a09", "c", "dry")); k <- intersect(names(p), names(b)); (p[k] - b[k]) / eps_vec(k) }; uM <- M / sqrt(sum(M^2))
rn <- function(nm) { for (d in c(file.path(POUT, "runs"), R)) { f <- file.path(d, paste0(nm, ".rds")); if (file.exists(f)) return(readRDS(f)) }; NULL }
for (cs in c("dry", "dry-p50", "dry-flat", "episodic", "long-drought", "long-wet", "episodic-lma", "ld-102", "ld-105", "wet-adG2")) {
  ref <- refq(cs)
  for (pr in list(c("P_insc_", "P_insf_", "P_ins3c_", "P_ins3f_", "ins"), c("val_a09_c_", "val_a09_f_", "val_a09h_c_", "val_a09h_f_", "a09"))) {
    x <- lapply(pr[1:4], function(t) rn(paste0(t, cs))); if (any(vapply(x, is.null, TRUE))) next
    same <- isTRUE(all.equal(x[[1]]$node_times, x[[3]]$node_times)) && isTRUE(all.equal(x[[2]]$node_times, x[[4]]$node_times))
    q <- lapply(x, quantities); k <- Reduce(intersect, c(list(names(ref), names(uM)), lapply(q, names))); e <- eps_vec(k); u <- uM[k] / sqrt(sum(uM[k]^2))
    tc <- (q[[3]][k] - q[[1]][k]) / e; tf <- (q[[4]][k] - q[[2]][k]) / e; ec <- (q[[1]][k] - ref[k]) / e; dd <- tc - tf
    on <- function(v) sum(v * u); sh <- function(v) on(v)^2 / sum(v^2)
    cat(sprintf("%-13s %s same %d | tol_c rms %.3f (M %+.2f) tol_f rms %.3f (M %+.2f) | corr %.2f | c-f diff rms %.3f, on M %+.2f (share %.2f) | err_c on M %+.2f, cos(diff, err_c) %+.2f\n",
      cs, pr[5], same, sqrt(mean(tc^2)), on(tc), sqrt(mean(tf^2)), on(tf), cor(tc, tf), sqrt(mean(dd^2)), on(dd), sh(dd), on(ec), sum(dd * ec) / sqrt(sum(dd^2) * sum(ec^2))))
  } }
