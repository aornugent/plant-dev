# lib_sw's adaptive run at soil x10 on long drought (stand alone) against the
# driver's soil-x10 program (phase1a/runs/ck10_3e-5.rds), whose plant replay
# (phase1a/plant/ck10_3e-5.rds) had finite gradients: J and every step.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
drv <- readRDS(file.path(D, "phase1a/runs/ck10_3e-5.rds"))
rep <- readRDS(file.path(D, "phase1a/plant/ck10_3e-5.rds"))
sw <- readRDS(file.path(D, "phase1c/combined/full/chk_ld_soil10_forward.rds"))
t_sw <- sw$stand$times
t_drv <- c(0, drv$st$time)
cat(sprintf("driver: J %.12f, %d accepted | replay: J %.12f, %d steps | lib_sw adaptive: J %.12f, %d steps\n",
            drv$J, nrow(drv$st), rep$stand$J, length(rep$stand$times), sw$stand$J, length(t_sw)))
n <- min(length(t_sw), length(t_drv))
d <- which(t_sw[1:n] != t_drv[1:n])[1]
cat("step times identical to the driver's:", identical(t_sw, t_drv),
    if (!is.na(d)) sprintf("; first differs at step %d (t = %.6f vs %.6f)", d, t_sw[d], t_drv[d]) else "", "\n")
cat("step times identical to the replay's:", identical(t_sw, rep$stand$times), "\n")
