# q1_shrink.R: on every stored committed/check pair, the measured shrink of the error from
# committed to check (f on c, least squares over quantities) against the pilot proxy's s,
# overall and by quantity group (leaf, hydraulic M, ln J). Reads the order in real pairs.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
CK <- readRDS(file.path(OUT, "q4_check.rds")); R <- CK$R; EST <- CK$EST
HYD <- c("a_l1", "root_P50", "omega", "root_c", "stem_c", "storage_relaxation_offset"); LEAF <- c("a", "curv_fact_elec_trans", "k_I", "jmax_25", "lma", "vcmax_25", "R_d_25")
sh <- function(ef, ec) sum(ef * ec) / sum(ec^2)
S <- do.call(rbind, lapply(seq_len(nrow(R)), function(i) { z <- EST[[i]]; k <- z$k
  data.frame(case = R$case[i], fam = R$fam[i], build = R$build[i], tol = R$tol[i], s = z$s, s_all = sh(z$ef, z$ec), s_hyd = sh(z$ef[k %in% HYD], z$ec[k %in% HYD]),
    s_leaf = sh(z$ef[k %in% LEAF], z$ec[k %in% LEAF]), s_lnJ = z$ef["lnJ"] / z$ec["lnJ"], rms_c = R$rms_c[i]) }))
S <- S[S$rms_c > 0.1, ]
f <- function(x) sprintf("%.2f [%.2f, %.2f]", median(x), quantile(x, 0.1), quantile(x, 0.9))
cat(nrow(S), "pairs with committed rms > 0.1 eps\n")
cat("  proxy s:               ", f(S$s), "\n  measured, all:         ", f(S$s_all), "\n  measured / proxy:      ", f(S$s_all / S$s), "\n")
cat("  measured, hydraulic:   ", f(S$s_hyd), "\n  measured, leaf:        ", f(S$s_leaf), "\n  measured, ln J:        ", f(S$s_lnJ), "\n")
for (b in unique(S$build)) { j <- S$build == b; cat(sprintf("  build %-4s n %3d  measured/proxy %s | hyd %s | leaf %s\n", b, sum(j), f(S$s_all[j] / S$s[j]), f(S$s_hyd[j]), f(S$s_leaf[j]))) }
for (fm in c("a09", "a10", "c5t", "a09h", "a10h", "P_ins", "P_ins3", "P_mid", "AG_a09", "AG_ins", "ins75")) { j <- S$fam == fm; if (sum(j) < 2) next
  cat(sprintf("  family %-7s n %2d  s %s | measured %s | hyd %s | leaf %s\n", fm, sum(j), f(S$s[j]), f(S$s_all[j]), f(S$s_hyd[j]), f(S$s_leaf[j]))) }
