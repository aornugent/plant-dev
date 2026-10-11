# The panels of P the map rates low but bisection moves most: largest 4 (P-B) - e_P in
# the soil part, with their span, the creation state around them and P's nodes.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
pe <- function(x) { b <- nd(x); j <- x$dropped; data.frame(t = x$node_times[j], own = own_drop(b, j) / sum(b$w * b$offspring),
  soil = colSums(x$soil) / x$stand$J, light = colSums(x$light) / x$stand$J) }
xp <- run("ref_u108e_episodic_p3"); xb <- run("rcB_u108e_episodic_p3"); t <- xp$node_times; j <- xp$dropped; a <- pe(xp); bb <- pe(xb)
cr <- readRDS(file.path(D, "schedtest/placed2/runs/fwd_u108e_p3_episodic.rds"))$stand$creation
rate <- approxfun(cr$start, cr$rate, method = "constant", rule = 2)
lo <- t[j - 1]; hi <- t[j + 1]
pb <- t(sapply(seq_along(j), function(i) { s <- bb$t > lo[i] & bb$t < hi[i]; colSums(bb[s, c("own", "soil", "light")]) }))
gap <- 4 * pb[, "soil"] - a$soil; o <- order(gap)[1:8]
open_frac <- function(l, h) mean(rate(seq(l, h, length.out = 200)) > 0.01)
print(data.frame(lo = round(lo[o], 3), mid = round(t[j[o]], 3), hi = round(hi[o], 3), left_d = round((t[j[o]] - lo[o]) * 365), right_d = round((hi[o] - t[j[o]]) * 365),
  open_left = round(mapply(open_frac, lo[o], t[j[o]]), 2), open_right = round(mapply(open_frac, t[j[o]], hi[o]), 2),
  eP = round(a$soil[o] / .025, 3), PB4 = round(4 * pb[o, "soil"] / .025, 3)), row.names = FALSE)
cat(sprintf("these 8 carry %.3f of the %.3f eps soil shortfall\n", sum(gap[o]) / .025, sum(gap) / .025))
saveRDS(data.frame(lo = lo[o], hi = hi[o]), file.path(D, "schedtest/rc/missed.rds"))
