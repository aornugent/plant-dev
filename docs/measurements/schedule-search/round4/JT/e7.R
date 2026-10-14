# e7.R: arm-switch traffic inside A's steps, by the splice windows.
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
r <- as.data.frame(readRDS(file.path(O, "tl_A.rds"))); r <- r[!is.na(r$t), ]
k <- 2:nrow(r); h <- r$t[k] - r$t[k - 1]; ok <- h > 0 & r$nodes[k] == r$nodes[k - 1]
m <- abs(r$crit[k] - r$crit[k - 1]); m[!ok] <- 0
brk <- c(0, 1, 3.5, 5, 6.7, 8.25, 9.15, 9.678, 9.753, 10.04, 17, 25, 40)
share <- c("~0", "~0", "16%", "~0", "9%", "~0", "~0", "30%", "4%", "38%", "~0", "~0")
w <- cut(r$t[k], brk)
d <- data.frame(window = levels(w), jitter_share = share,
  switches = tapply(m, w, sum), in_long_steps = tapply(m * (h > 1 / 365), w, sum),
  m_h_days = tapply(m * h * 365, w, sum), max_in_one_step = tapply(m, w, max), nodes_end = tapply(r$nodes[k], w, max))
print(d, row.names = FALSE)
big <- which(m >= 5 & h > 0.5 / 365); cat("\nsteps holding >= 5 switches and longer than 0.5 d:\n")
print(data.frame(t0 = r$t[k - 1][big], h_d = h[big] * 365, switches = m[big], crit_from = r$crit[k - 1][big], crit_to = r$crit[k][big], nodes = r$nodes[k][big]), digits = 5)
