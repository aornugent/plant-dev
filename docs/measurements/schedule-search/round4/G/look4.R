# look4.R: what sets the step size by patch age: tolerance, the 15 d cap, or the record?
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
br <- c(0, 2, 5, 10, 20, 25, 30, 35, 40); hmax <- 15 / 365
for (nm in c("dry", "episodic", "long-wet", "ld-102")) {
  x <- readRDS(file.path(AR, sprintf("val_a09_c_%s.rds", nm))); t <- x$stand$times; h <- c(NA, diff(t)); bd <- cut(t, br, right = FALSE)
  f <- function(v) sprintf("%5.2f", v)
  cat(sprintf("%-9s share %s tol %s\n", nm, x$setting$env["SHARE"], x$setting$tol))
  cat("  median h (d):  ", f(tapply(h * 365, bd, median, na.rm = TRUE)), "\n")
  cat("  frac at cap:   ", f(tapply(h > 0.98 * hmax, bd, mean, na.rm = TRUE)), "\n")
  cat("  frac < 1 d:    ", f(tapply(h < 1 / 365, bd, mean, na.rm = TRUE)), "\n")
  cat("  steps per year:", f(tapply(rep(1, length(t)), bd, sum) / diff(br)), "\n")
  sl <- x$stand$input_slopes; nz <- vapply(sl, function(s) any(s != 0), TRUE)
  cat("  frac steps with nonzero soil input:", f(tapply(nz, bd, mean)), "\n") }
cat("bands", br, "\n")
