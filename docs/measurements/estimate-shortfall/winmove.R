# J's move from refining two late windows to 1-7 day spacing (the scan) against the
# square-law prediction from the bisection map: 4/3 of those windows' share of P - B.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
Q <- file.path(D, "schedtest/placed2/runs")
xp <- run("ref_u108e_episodic_p3"); xb <- run("rcB_u108e_episodic_p3"); xs <- readRDS(file.path(Q, "rc_winscan_episodic.rds"))
w <- readRDS(file.path(D, "schedtest/rc/winscan_windows.rds"))
b <- nd(xb); j <- xb$dropped; tb <- xb$node_times[j]
own <- own_drop(b, j) / sum(b$w * b$offspring); li <- colSums(xb$light) / xb$stand$J; so <- colSums(xb$soil) / xb$stand$J
inw <- Reduce(`|`, lapply(seq_len(nrow(w)), function(i) tb > w[i, 1] & tb < w[i, 2]))
# the map on B predicts P - B = sum of (own + field) over B's dropped nodes, as C_B - B with C_B = P
share <- c(own = sum(own[inw]), light = sum(li[inw]), soil = sum(so[inw]))
cat(sprintf("P - B from these windows (map on B): own %+.4f light %+.4f soil %+.4f eps\n", share[1] / .025, share[2] / .025, share[3] / .025))
cat(sprintf("square-law prediction for refining them fully: ln J(fine) - ln J(P) = %+.4f eps\n", -4 / 3 * sum(share) / .025))
cat(sprintf("measured (scan, 1-7 day spacing): %+.4f eps\n", (log(xs$stand$J) - log(xp$stand$J)) / .025))
