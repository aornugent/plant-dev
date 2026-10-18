suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
D <- commandArgs(TRUE)[1]; if (is.na(D)) D <- file.path(SP, "refine/s1")
qs <- c("a_l1", "a", "k_I", "jmax_25", "curv_fact_elec_trans", "lnJ", "hmat", "k_s", "storage_relaxation_offset", "a_st3", "lma", "R_d_25", "TF24_cost_scale", "root_P50")
out <- sapply(c("dry", "long-wet", "episodic-lma", "dry-flat", "epi-adG208"), function(cs) {
  f <- file.path(D, paste0(cs, ".rds")); if (!file.exists(f)) return(rep(NA, 2 * length(qs)))
  h <- readRDS(f)$history[[1]]; R <- ref_ladder(cs); err <- (h$answer[Q] - R$ref) / EPS
  c(setNames(round(err[qs], 2), paste0("err.", qs)), setNames(round(h$estimate[qs] / err[qs], 2), paste0("read.", qs))) })
print(out)
