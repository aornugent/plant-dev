# Fate inside two late windows from the dense scan: per node, net reproduction,
# end height, end mortality, sign-change count; and where P3's nodes sit.
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
x <- readRDS(file.path(S, "placed2/runs/rc_winscan_episodic.rds")); n <- x$stand$nodes; m <- length(n$birth)
w <- readRDS(file.path(S, "rc/winscan_windows.rds")); t3 <- readRDS(file.path(S, "refine/ref_u108e_episodic_p3_times.rds"))
cr <- x$stand$creation; rate <- approxfun(cr$start, cr$rate, method = "constant", rule = 2)
for (i in seq_len(nrow(w))) {
  k <- which(n$birth >= w[i, 1] - 1e-9 & n$birth <= w[i, 2] + 1e-9)
  d <- data.frame(day = round((n$birth[k] - w[i, 1]) * 365, 1), rate = signif(rate(n$birth[k] + 1e-9), 3), nrr = signif(n$nrr[k], 3),
                  height = round(n$height[k], 2), mort = round(n$mortality[k], 2), splits = x$stand$splits[k], P3 = round(n$birth[k], 9) %in% round(t3, 9))
  cat(sprintf("\n== window %d: %.3f-%.3f (%.0f days), %d scan nodes, %d of P3's\n", i, w[i, 1], w[i, 2], (w[i, 2] - w[i, 1]) * 365, length(k), sum(d$P3)))
  sel <- unique(c(1:min(25, nrow(d)), which(d$P3), seq(26, nrow(d), by = 6)))
  print(d[sort(sel[sel <= nrow(d)]), ], row.names = FALSE)
}
