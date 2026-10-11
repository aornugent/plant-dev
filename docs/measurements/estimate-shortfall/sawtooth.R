# Layer-1 water, scan minus pass 3, weekly through panel 1 (P3 nodes at 7.985, 8.148,
# 8.519), with the uptake share of the soil's flows from the creation record's time.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
a <- readRDS(file.path(S, "placed2/runs/fwd_u108e_p3_episodic.rds"))$stand$soil
b <- readRDS(file.path(S, "placed2/runs/rc_missscan_episodic.rds"))$stand$soil
g <- seq(7.95, 8.65, by = 7 / 365); th <- function(s, k) approx(s$time, s$theta[, k], g, ties = "ordered", rule = 2)$y
print(data.frame(t = round(g, 3), days_since_P3_node = round(365 * (g - c(7.985, 8.148, 8.519)[pmax(1, findInterval(g, c(7.985, 8.148, 8.519)))])),
  theta1_P3 = round(th(a, 1), 4), diff1 = signif(th(b, 1) - th(a, 1), 2), diff3 = signif(th(b, 3) - th(a, 3), 2)), row.names = FALSE)
