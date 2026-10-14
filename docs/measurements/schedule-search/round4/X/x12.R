# x12.R: the X1 nudges and X2 founders' year against the inset pair at 1e-4 and 3e-4 on
# dry: each run's move from 3e-4 as a share of the 1e-4 -> 3e-4 move (rms over quantities,
# and on the leaf quantities), and the pair's read with each run swapped in.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
XR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/runs"
ld <- function(n) { f <- file.path(XR, paste0(n, ".rds")); if (!file.exists(f)) f <- file.path(POUT, "runs", paste0(n, ".rds")); if (file.exists(f)) readRDS(f) }
ref <- refq("dry"); leaf <- c("a_l1", "a_y", "a_bio", "lma", "a", "k_I", "jmax_25", "curv_fact_elec_trans")
for (v in c("c", "f")) { b1 <- quantities(ld(paste0("P_ins", v, "_dry"))); b3 <- quantities(ld(paste0("P_ins3", v, "_dry")))
  k <- Reduce(intersect, list(names(ref), names(b1), names(b3))); e <- eps_vec(k); t3 <- (b3[k] - b1[k]) / e; kl <- intersect(leaf, k)
  cat(sprintf("%s: 1e-4 -> 3e-4 rms %.3f, leaf rms %.3f\n", v, sqrt(mean(t3^2)), sqrt(mean(t3[kl]^2))))
  for (x in c("2.85e-4", "3.15e-4", "f3")) { r <- ld(sprintf("X_ins3%s_%s_dry", v, x)); if (is.null(r) || is.null(r$stand$elasticity)) next
    m <- (quantities(r)[k] - b3[k]) / e; cat(sprintf("   %-8s move from 3e-4: rms %.3f (%.0f%% of the tolerance move), leaf rms %.3f (%.0f%%); toward 1e-4: %.0f%% (projection)\n", x,
      sqrt(mean(m^2)), 100 * sqrt(mean(m^2)) / sqrt(mean(t3^2)), sqrt(mean(m[kl]^2)), 100 * sqrt(mean(m[kl]^2)) / sqrt(mean(t3[kl]^2)), -100 * sum(m * t3) / sum(t3^2))) } }
