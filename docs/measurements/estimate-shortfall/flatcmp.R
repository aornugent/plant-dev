# Seasonal against non-seasonal episodic, u108 + edges: coarsening (edges kept, and
# every other node) against bisection, in eps of ln J.
Q <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/placed2/runs"
lj <- function(n) log(readRDS(file.path(Q, paste0(n, ".rds")))$stand$J)
for (cs in list(c("seasonal", "rc_seas_%s_episodic"), c("flat", "flat_run_%s"))) {
  g <- function(k) lj(sprintf(cs[2], k)); p <- g("P"); b <- g("B"); cp <- g("Cp"); co <- g("Co")
  cat(sprintf("%-8s P-B %+.4f | Cp-P %+.4f (ratio %.2f) | Co-P %+.4f (ratio %.2f) eps\n", cs[1], (p - b) / .025, (cp - p) / .025, (cp - p) / (p - b), (co - p) / .025, (co - p) / (p - b))) }
