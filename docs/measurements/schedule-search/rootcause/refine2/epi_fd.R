# a_l1's integrand along birth date at level 2: per node, d(w nrr)/d ln a_l1 by a 1% forward difference.
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/epi"
a <- readRDS(file.path(E, "runs/fd_base.rds"))$stand; b <- readRDS(file.path(E, "runs/fd_al1.rds"))$stand
n <- length(a$nodes$birth); w0 <- a$nodes$establishment[1:n]; w1 <- b$nodes$establishment[1:n]
c0 <- w0 * a$nodes$nrr; c1 <- w1 * b$nodes$nrr
cat("J", a$J, b$J, "elasticity (FD, ln J)", log(b$J / a$J) / log(1.01), " sum of node parts / J", sum(c1 - c0) / log(1.01) / a$J, "\n")
S <- readRDS(file.path(E, "schedules.rds"))$s05; br <- S$breaks
d <- data.frame(b = a$nodes$birth, nrr = a$nodes$nrr, w = w0, g_fate = w0 * (b$nodes$nrr - a$nodes$nrr) / log(1.01) / a$J,
                g_w = (w1 - w0) * a$nodes$nrr / log(1.01) / a$J)
d$g <- d$g_fate + d$g_w; d$panel <- findInterval(d$b, br + 1e-9)
# per unit birth date: divide by the node's weight share of the interval width
h <- c(diff(d$b), NA); hm <- (c(NA, head(h, -1)) + h) / 2; d$rel <- (b$nodes$nrr - a$nodes$nrr) / a$nodes$nrr / log(1.01)
saveRDS(d, file.path(E, "fd_integrand.rds"))
reg <- cut(d$b, c(0, 3.2, 6.6, 12.6, 17.7, 24.5, 40), labels = c("A", "B", "C", "D", "E", "F"))
print(round(tapply(d$g, reg, sum), 4)); print(round(tapply(d$g_w, reg, sum), 4))
options(width = 200)
for (lo in c(7.985, 12.806, 10.031)) { k <- d$panel == findInterval(lo + 1e-6, br + 1e-9); cat("\npanel from", lo, "\n")
  print(format(data.frame(b = round(d$b[k], 3), nrr = d$nrr[k], rel_dnrr = d$rel[k], g_fate = d$g_fate[k], g_w = d$g_w[k]), digits = 3), row.names = FALSE) }
