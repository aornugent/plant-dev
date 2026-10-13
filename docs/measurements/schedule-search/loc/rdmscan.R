# ln J at rooting_depth_max x (1+u) on G0's own steps: one-sided slopes against u.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
us <- c(-0.02, -0.01, -0.005, -0.002, 0.002, 0.005, 0.01, 0.02)
J0 <- readRDS(file.path(A, "loc_G0_dry.rds")); l0 <- log(J0$stand$J); el <- J0$stand$elasticity[grep("rooting_depth_max", names(J0$stand$elasticity))]
d <- do.call(rbind, lapply(us, function(u) { f <- file.path(A, sprintf("loc_rdmscan_dry_%s.rds", u)); if (!file.exists(f)) return(NULL)
  x <- readRDS(f); data.frame(u = u, slope = (log(x$stand$J) - l0) / log1p(u)) }))
cat(sprintf("sweep elasticity at u = 0: %.5f\n", el)); print(round(d, 5))
