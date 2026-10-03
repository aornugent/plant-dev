# Decisive run (a) on the tol 1e-7 reference's steps: the lockstep replays against
# that run (built on lib_v12t; the replays on the probe build).
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
m <- readRDS(file.path(D, "ark/ck_u108_1e-7.rds"))
for (nm in c("lock_true_ref1e-7", "lock_helddef_ref1e-7")) {
  l <- readRDS(file.path(D, "partition_bias/out", paste0(nm, ".rds")))
  soil_m <- as.matrix(m$st[, paste0("soil_", 1:5)])
  soil_l <- as.matrix(l$st[, paste0("soil_", 1:5)])
  cat(sprintf("%s: J identical %s (relative %.3g); per-node fecundity identical %s (max rel %.3g); soil at every step end identical %s (max rel %.3g)\n",
              nm, identical(l$J, m$J), (l$J - m$J) / m$J, identical(l$by_node$fecundity, m$by_node$fecundity),
              max(abs(l$by_node$fecundity / m$by_node$fecundity - 1)), identical(unname(soil_l), unname(soil_m)),
              max(abs(soil_l / soil_m - 1))))
}
