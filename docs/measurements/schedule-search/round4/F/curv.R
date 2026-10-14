# Offline scale of the midpoint term: q(x) = q0 + q1 x + q2 x^2/2 along x = ln(lma ratio) on
# episodic, from the references at x = 0 and ln 1.25 and the slope from the +-1% map runs.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
r0 <- reference("episodic"); r1 <- reference("episodic-lma")
qp <- quantities(readRDS(file.path(R, "map_e215_lma+.rds"))); qm <- quantities(readRDS(file.path(R, "map_e215_lma-.rds"))); q0 <- quantities(readRDS(file.path(R, "map_e215.rds")))
k <- Reduce(intersect, list(names(r0), names(r1), names(qp))); e <- eps_vec(k)
x1 <- log(1.25); dx <- log(1.01) - log(0.99)
slope <- (qp[k] - qm[k]) / dx                      # dq/dx at x = 0 (on u215)
mid1 <- ((qp[k] + qm[k]) / 2 - q0[k]) / e           # the +-1% midpoint term itself
q2 <- 2 * (r1[k] - r0[k] - slope * x1) / x1^2
for (dl in c(0.1, 0.2)) { term <- 0.5 * dl^2 * q2 / e
  cat(sprintf("delta %.1f: |midpoint term| median %.3f, 90%% %.3f, max %.2f eps (%s)\n", dl, median(abs(term)), quantile(abs(term), 0.9), max(abs(term)), k[which.max(abs(term))])) }
cat(sprintf("lnJ: episodic %.3f, episodic-lma %.3f (elasticity of lma %.2f)\n", r0["lnJ"], r1["lnJ"], r0["lma"]))
cat(sprintf("first difference over x 0 -> ln1.25, in eps: median %.2f, max %.1f\n", median(abs((r1[k] - r0[k]) / e)), max(abs((r1[k] - r0[k]) / e))))
cat(sprintf("+-1%% midpoint in eps (noise floor x 1e4 scaling would be useless): median %.3f max %.3f\n", median(abs(mid1)), max(abs(mid1))))
o <- order(-abs(q2 / e))[1:8]; print(data.frame(q = k[o], first_diff_eps = round(((r1[k] - r0[k]) / e)[o], 1), slope_x1_eps = round((slope * x1 / e)[o], 1), term10 = round((0.5 * 0.01 * q2 / e)[o], 1)))
