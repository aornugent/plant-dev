# When do the top cohorts earn their offspring, and how combed are they then?
# From the committed layer_ld_G1.rds (layer_heights.R on G1).
x <- readRDS("/home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba/docs/measurements/creation-grid/layer_ld_G1.rds")
cat("G1 nodes kept:", length(x$times), " eta:", x$eta, " J:", x$J, "\n")
j <- 1
off <- x$offspring[, j]
tt <- x$grid
fin <- tail(off[!is.na(off)], 1)
q <- sapply(c(0.1, 0.25, 0.5, 0.75, 0.9), function(p) tt[which(off >= p * fin)[1]])
cat(sprintf("node born %.3f: offspring reaches 10/25/50/75/90%% of its final at t = %s\n", x$times[j],
            paste(sprintf("%.2f", q), collapse = ", ")))
# Overlap ratio at those times for uniform spacing 0.37 and 0.185 (heights from G1 interpolated)
ov <- function(t, s) {
  i <- which.min(abs(tt - t)); h <- x$height[i, ]; ok <- !is.na(h)
  hh <- approx(x$times[ok], h[ok], s)$y
  (hh[1] - hh[2]) / (hh[1] / x$eta)
}
for (t in c(q, 15, 20, 30)) cat(sprintf("t %.2f: height of the first node %.2f m; overlap ratio first gap u108 %.2f, u215 %.2f, u429 %.2f\n",
                                     t, x$height[which.min(abs(tt - t)), 1], ov(t, c(0, 40/108)), ov(t, c(0, 20/108)), ov(t, c(0, 10/108))))
