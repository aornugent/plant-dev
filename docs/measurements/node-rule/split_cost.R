# What the spread costs the split (prereg.txt, "The split's cost with the spread"),
# from split_cost.sh's runs: each phase's seconds, the two repeats' mean.
#   DEV=... Rscript split_cost.R
O <- file.path(Sys.getenv("DEV"), "node_rule", "split_cost", "runs")
secs <- function(name, phase) {
  mean(vapply(1:2, function(k) readRDS(file.path(O, sprintf("%s_%d.rds", name, k)))$phases[[phase]]$secs, 0))
}
for (phase in c("stand_run", "stand_gradient")) {
  s <- vapply(c("split_lumped", "split_spread", "plain_lumped", "plain_spread"), secs, 0, phase = phase)
  cat(sprintf("%-14s lumped %.1f / %.1f s, spread %.1f / %.1f s (split / plain): the spread costs %+.1f%% split, %+.1f%% plain; the split costs %+.1f%% lumped, %+.1f%% spread\n",
              phase, s[1], s[3], s[2], s[4], 100 * (s[2] / s[1] - 1), 100 * (s[4] / s[3] - 1),
              100 * (s[1] / s[3] - 1), 100 * (s[2] / s[4] - 1)))
}
