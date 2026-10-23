# The leaf's inputs along real trajectories: the sampled log of every 10th leaf
# call in a resident run and a run_mutant over pool rows 1-3 (row 1 is the
# resident's own traits). Writes inputs.rds (a thinned sample) and prints the
# ranges and the soil-compression checks.
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table/common.R")

d <- read_leaflog(Sys.glob(file.path(TMP, "leaflog.*.bin")))
# The resident's own run is the first segment: it ends where time first resets.
reset <- which(diff(d$time) < -1)[1]
d$phase <- ifelse(seq_len(nrow(d)) <= reset, "resident", "run_mutant")
d$who <- ifelse(abs(d$vcmax_25 - TRAIT0[["vcmax_25"]]) < 1e-9 &
                  abs(d$lma - TRAIT0[["lma"]]) < 1e-12, "resident traits",
                sprintf("invader vcmax %.1f", d$vcmax_25))
d$P <- d$profit + d$shadow
cat("rows", nrow(d), "\n")
print(table(d$phase, d$who))
cat("replayed rows:", sum(d$replayed), "\n")
cat("drivers: vpd", range(d$vpd), " ca", range(d$ca), " leaf_temp", range(d$leaf_temp),
    " PPFD", range(d$PPFD), "\n")

q <- function(x) signif(quantile(x, c(0, 0.01, 0.5, 0.99, 1), na.rm = TRUE), 3)
for (g in split(d, paste(d$phase, d$who))) {
  cat("\n==", g$phase[1], g$who[1], " n =", nrow(g), "\n")
  print(rbind(height = q(g$height), light = q(g$light), psi1 = q(g$psi1),
              psi3 = q(g$psi3), psi5 = q(g$psi5), kmax = q(g$kmax),
              P = q(g$P), E = q(g$E), root_psi = q(g$root_psi)))
  cat("kinds:"); print(table(g$kind))
}

# Soil: how far the layers spread, and the weighted mean the supply sees.
W <- t(vapply(d$height, root_weights, numeric(5),
              rooting_depth_max = TRAIT0[["rooting_depth_max"]]))
psi <- as.matrix(d[paste0("psi", 1:5)])
d$psi_w <- rowSums(W * psi)
d$psi_spread <- apply(psi, 1, max) - apply(psi, 1, min)
cat("\nlayer-1 weight: "); print(q(W[, 1]))
cat("psi spread across layers (MPa): "); print(q(d$psi_spread))
cat("psi_w (MPa): "); print(q(d$psi_w))
cat("share of water drawn from layer 1: "); print(q(d$u1 / rowSums(d[paste0("u", 1:5)])))

set.seed(1)
keep <- unlist(lapply(split(seq_len(nrow(d)), paste(d$phase, d$who)),
                      function(i) i[sort(sample.int(length(i), min(length(i), 20000)))]))
saveRDS(d[keep, ], file.path(TMP, "inputs.rds"))
saveRDS(d[d$phase == "resident", ], file.path(TMP, "resident_calls.rds"))
