# Each region's share of a level difference: region-mixed replay minus its base run, in eps.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
E <- file.path(SP, "epi"); O <- file.path(SP, "refine/s05/epi-adG208")
a <- commandArgs(TRUE); pre <- a[1]; base <- a[2]; full <- a[3]   # e.g. l1m level1 level0_on_level1_steps
rd <- function(f) { x <- readRDS(f); if (is.null(x$finished)) NULL else qv(x) / EPS }
qb <- rd(file.path(O, paste0(base, ".rds"))); if (is.null(qb)) qb <- rd(file.path(E, "runs", paste0(base, ".rds")))
D <- sapply(c("A", "B", "C", "D", "E", "F"), function(R) { f <- file.path(E, "runs", sprintf("%s_%s.rds", pre, R)); if (!file.exists(f)) return(rep(NA, length(Q))); q <- rd(f); if (is.null(q)) rep(NA, length(Q)) else q - qb })
rownames(D) <- Q; tot <- if (!is.na(full)) { qf <- rd(file.path(O, paste0(full, ".rds"))); if (is.null(qf)) qf <- rd(file.path(E, "runs", paste0(full, ".rds"))); qf - qb } else NA
out <- data.frame(round(D, 3), sum = round(rowSums(D), 3), full = round(tot, 3))
qs <- c("a_l1", "lnJ", "a", "k_I", "jmax_25", "curv_fact_elec_trans", "lma", "R_d_25", "storage_relaxation_offset", "k_s", "r_s", "hmat", "a_st3", "TF24_cost_scale", "a_dG1", "root_P50")
options(width = 200); print(out[qs, ]); cat("max |sum - full| over all quantities:", round(max(abs(out$sum - out$full)), 3), "\n")
saveRDS(D, file.path(E, paste0("D_", pre, ".rds")))
