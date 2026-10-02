# Checks the driver's chain_ratio (t3_driver.patch) against T1's chain-alone ratio
# on a few first-day rejections, by sourcing the driver without running it.
#   cd WORKTREE && PLANT_LIB=DEV/lib_probe TOL=3e-5 ATOL=1e-4 CONTROL=pi nice -n 10 Rscript DEV/rej_class/t3_check.R
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
source("harness/ark_prototype.R")
b <- readRDS(file.path(O, "t1_rejected_pics_3e-5.rds"))
i <- c(1, 100, 400, 700)
th <- as.matrix(b[i, paste0("theta", 1:5)])
got <- vapply(seq_along(i), function(j) chain_ratio(th[j, ], b$t0[i[j]], b$h[i[j]]), 0)
print(cbind(t1 = b$chain[i], driver = got, rel = got / b$chain[i] - 1))
