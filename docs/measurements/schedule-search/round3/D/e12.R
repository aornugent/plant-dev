O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/D_out/"
cmp <- function(r) {
  a <- readRDS(paste0(O, "e12_", r, "_base.rds"))$soil; b <- readRDS(paste0(O, "e12_", r, "_pert.rds"))$soil
  stopifnot(identical(a$time, b$time))
  d <- abs(a$theta[, 1] - b$theta[, 1]); t <- a$time
  br <- c(0, 10, 30, 36.9, 37.04, 37.06, 37.065, 37.0685, 37.0712, 37.074, 37.0767, 37.0795, 37.0822, 37.085, 37.1, 37.5, 38, 40.1)
  g <- cut(t, br)
  cat("==", r, "\n"); print(round(log10(tapply(d, g, max) + 1e-300), 2))
  cat("all layers, max |dtheta| over [37.06,37.09]:", sapply(1:5, function(L) max(abs(a$theta[t > 37.06 & t < 37.09, L] - b$theta[t > 37.06 & t < 37.09, L]))), "\n")
}
for (r in commandArgs(TRUE)) cmp(r)
