# Top-layer and layer-2 water: the dense-scan run minus pass 3's run, by time band.
# The scan adds nodes only within [7.985, 8.519] and [14.074, 14.448].
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
a <- readRDS(file.path(S, "placed2/runs/fwd_u108e_p3_episodic.rds"))$stand$soil
b <- readRDS(file.path(S, "placed2/runs/rc_missscan_episodic.rds"))$stand$soil
g <- seq(0, 40, by = 1 / 365); th <- function(s, k) approx(s$time, s$theta[, k], g, ties = "ordered", rule = 2)$y
br <- c(0, 7.985, 8.25, 8.519, 9, 10, 12, 14.074, 14.448, 15, 17, 20, 40)
for (k in 1:3) { d <- th(b, k) - th(a, k)
  cat(sprintf("layer %d: max |diff| %.2e at t = %.3f\n", k, max(abs(d)), g[which.max(abs(d))]))
  print(signif(tapply(abs(d), cut(g, br), max), 2)) }
