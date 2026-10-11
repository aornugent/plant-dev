# ln J move from refining the two missed panels to 2-day spacing, against 4/3 of their
# share of P - B (map on B) and against their coarsening move e_P (map on P).
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
Q <- file.path(D, "schedtest/placed2/runs"); m <- readRDS(file.path(D, "schedtest/rc/missed.rds"))[1:2, ]
pe <- function(x) { b <- nd(x); j <- x$dropped; data.frame(t = x$node_times[j], e = own_drop(b, j) / sum(b$w * b$offspring) + colSums(x$light + x$soil) / x$stand$J) }
xp <- run("ref_u108e_episodic_p3"); xb <- run("rcB_u108e_episodic_p3"); xs <- readRDS(file.path(Q, "rc_missscan_episodic.rds")); xf <- readRDS(file.path(Q, "fwd_u108e_p3_episodic.rds"))
inp <- function(t) (t > m$lo[1] & t < m$hi[1]) | (t > m$lo[2] & t < m$hi[2])
a <- pe(xp); b <- pe(xb)
cat(sprintf("forward P3 J vs map-run P3 J: %.3e relative\n", xf$stand$J / xp$stand$J - 1))
cat(sprintf("e_P in the two panels %+.4f eps; 4/3 x (P-B) share %+.4f eps; measured scan - P3 %+.4f eps\n",
  sum(a$e[inp(a$t)]) / .025, -4 / 3 * sum(b$e[inp(b$t)]) / .025, (log(xs$stand$J) - log(xf$stand$J)) / .025))
