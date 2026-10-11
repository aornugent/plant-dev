# Fate across the two most-missed panels at 2-day spacing: net reproduction, end
# height and mortality, sign-change count, creation rate; P3's nodes flagged.
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
x <- readRDS(file.path(S, "placed2/runs/rc_missscan_episodic.rds")); n <- x$stand$nodes
m <- readRDS(file.path(S, "rc/missed.rds"))[1:2, ]; t3 <- readRDS(file.path(S, "refine/ref_u108e_episodic_p3_times.rds"))
cr <- x$stand$creation; rate <- approxfun(cr$start, cr$rate, method = "constant", rule = 2)
for (i in 1:2) {
  k <- which(n$birth >= m$lo[i] - 1e-9 & n$birth <= m$hi[i] + 1e-9)
  d <- data.frame(b = round(n$birth[k], 4), rate = signif(rate(n$birth[k] + 1e-9), 3), nrr = signif(n$nrr[k], 4), h = round(n$height[k], 3),
                  mort = round(n$mortality[k], 3), splits = x$stand$splits[k], P3 = round(n$birth[k], 9) %in% round(t3, 9))
  d$d2nrr <- c(NA, signif(diff(d$nrr, differences = 2), 2), NA)
  cat(sprintf("\n== panel %d: %.3f-%.3f\n", i, m$lo[i], m$hi[i])); print(d, row.names = FALSE)
}
