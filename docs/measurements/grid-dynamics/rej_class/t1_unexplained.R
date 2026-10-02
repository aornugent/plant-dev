# The first-day soil-bound 'other' rejections the chain alone would accept
# (its ratio <= 1.1): the candidates for a member-driven residue.
#   nice -n 10 Rscript DEV/rej_class/t1_unexplained.R
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
for (name in c("pics_3e-5", "pi_3e-5", "base_3e-5")) {
  b <- readRDS(file.path(O, paste0("t1_rejected_", name, ".rds")))
  u <- b[b$chain <= 1.1, ]
  cat(sprintf("\n== %s: %d of %d with the chain alone <= 1.1\n", name, nrow(u), nrow(b)))
  u$h <- u$h * 365
  print(u[, c("t0", "h", "since", "n_since", "after", "ratio", "chain", "layer", "chain_layer", "theta1", "theta2",
              "x_soil", "crossed")], digits = 3, row.names = FALSE)
}
