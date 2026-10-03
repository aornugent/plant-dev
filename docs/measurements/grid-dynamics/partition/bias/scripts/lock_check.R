# Decisive run (a): each lockstep replay against the monolithic run it replays.
#   Rscript lock_check.R name1 [name2 ...]
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
m <- readRDS(file.path(D, "split/out/mono_3e-5.rds"))
for (nm in commandArgs(TRUE)) {
  f <- file.path(D, "partition_bias/out", paste0(nm, ".rds"))
  if (!file.exists(f)) next
  l <- readRDS(f)
  soil_m <- as.matrix(m$st[, paste0("soil_", 1:5)])
  soil_l <- as.matrix(l$st[, paste0("soil_", 1:5)])
  cat(sprintf(paste0("%s: J identical %s (J - J_mono %.3g, relative %.3g); per-node fecundity identical %s ",
                     "(max rel %.3g); soil at every step end identical %s (max rel %.3g)\n"),
              nm, identical(l$J, m$J), l$J - m$J, (l$J - m$J) / m$J,
              identical(l$by_node$fecundity, m$by_node$fecundity),
              max(abs(l$by_node$fecundity / m$by_node$fecundity - 1)),
              identical(unname(soil_l), unname(soil_m)), max(abs(soil_l / soil_m - 1))))
}
