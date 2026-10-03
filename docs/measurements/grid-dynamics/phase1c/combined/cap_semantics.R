# Plant's native rule A with a 15-day cap (lib_sw probe) against the driver's
# (phase1c/drv/episodic_ruleA_h15): where the step times part, and the steps
# around there in days.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
pl <- readRDS(file.path(D, "phase1c/combined/full/probe_epi_ruleA_h15.rds"))$times
dv <- c(0, readRDS(file.path(D, "phase1c/drv/episodic_ruleA_h15.rds"))$st$time)
n <- min(length(pl), length(dv))
d <- which(pl[1:n] != dv[1:n])[1]
cat(sprintf("plant %d times, driver %d; first difference at index %s\n", length(pl), length(dv), d))
if (!is.na(d)) {
  i <- max(2, d - 4):min(n, d + 4)
  cat(sprintf("t        plant: %s\n", paste(sprintf("%.6f", pl[i]), collapse = " ")))
  cat(sprintf("t       driver: %s\n", paste(sprintf("%.6f", dv[i]), collapse = " ")))
  cat(sprintf("h (d)    plant: %s\n", paste(sprintf("%.3f", diff(pl)[i - 1] * 365), collapse = " ")))
  cat(sprintf("h (d)   driver: %s\n", paste(sprintf("%.3f", diff(dv)[i - 1] * 365), collapse = " ")))
}
