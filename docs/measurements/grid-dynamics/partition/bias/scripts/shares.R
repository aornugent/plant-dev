# How much of the stand's draw the two nodes whose weights move with time carry:
# the newest node and the boundary node, at reference states, from the probe's
# by-node shares (split_uptake_tf24 with by_node = TRUE). Also the weights' own
# change over a day, from the establishment integrals' rates.
#
#   PLANT_LIB=$DEV/split/lib NODES=108 Rscript shares.R
Sys.setenv(METHOD = "ck")
source("/home/user/plant-dev/.claude/worktrees/agent-a4e5afe75b72479f0/harness/ark_prototype.R")
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/ark"
ref_t <- readRDS(file.path(D, "ck_u108_1e-7.rds"))$st$time
ref_s <- readRDS(file.path(D, "ck_u108_1e-7_states.rds"))
probe <- c(0.2, 1.0, 3.5, 3.6, 8.5, 9.5, 20.5, 33.0, 39.5)
k <- 0L
for (leg in seq_along(times)) {
  patch$introduce_new_node(1L, times[leg])
  t_end <- if (leg < length(times)) times[leg + 1] else LIFETIME
  for (tp in probe[probe > times[leg] & probe <= t_end]) {
    i <- which.min(abs(ref_t - tp))
    y <- ref_s[[i]]
    if (length(y) != 9 * leg + 10) next
    patch$derivs(y, ref_t[i])
    held <- plant:::split_hold_tf24(patch)
    sh <- plant:::split_uptake_tf24(held, y[soil(y)], numeric(0), TRUE)
    tot <- colSums(sh)
    n <- nrow(sh)
    w <- patch$species[[1]]$establishment_weights
    cat(sprintf("t %.3f (%d nodes): stand draw %s; newest node %.2e and boundary node %.2e of it; their weights %.3g %.3g\n",
                ref_t[i], n - 1, paste(sprintf("%.3g", tot), collapse = " "),
                sum(sh[n - 1, ]) / sum(tot), sum(sh[n, ]) / sum(tot), w[n - 1], w[n]))
  }
  if (leg < length(times)) {
    # leave the patch at the leg's last state for the next introduction
    while (k < length(ref_t) && ref_t[k + 1] <= t_end + 1e-12) k <- k + 1L
    patch$derivs(ref_s[[k]], ref_t[k])
  }
}
