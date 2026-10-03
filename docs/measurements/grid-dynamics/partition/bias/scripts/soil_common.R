# A run's soil against the tol 1e-7 reference at the times both land on (knots
# and introductions), exactly, without interpolation: the largest relative
# differences per layer, when they occur, and their spread.
#
#   Rscript soil_common.R name1 [name2 ...]
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
rs <- readRDS(file.path(D, "ark", "ck_u108_1e-7.rds"))$st
key <- function(x) round(x * 1e9)
for (nm in commandArgs(TRUE)) {
  cand <- file.path(D, c("partition_bias/out", "split/out"), paste0(nm, ".rds"))
  st <- readRDS(cand[file.exists(cand)][1])$st
  common <- intersect(key(st$time), key(rs$time))
  iu <- match(common, key(st$time)); ir <- match(common, key(rs$time))
  d <- sapply(1:5, function(l) (st[[paste0("soil_", l)]][iu] - rs[[paste0("soil_", l)]][ir]) / rs[[paste0("soil_", l)]][ir])
  worst <- apply(abs(d), 2, which.max)
  cat(sprintf("%-22s %4d common | max |rel| by layer %s at t %s | median |rel| %s\n", nm, length(common),
              paste(sprintf("%.1e", apply(abs(d), 2, max)), collapse = " "),
              paste(sprintf("%.2f", st$time[iu][worst]), collapse = " "),
              paste(sprintf("%.1e", apply(abs(d), 2, median)), collapse = " ")))
}
