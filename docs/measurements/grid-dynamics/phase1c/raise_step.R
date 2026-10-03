# The program's step that holds each raise time: its start, length and the two
# steps before it, in days.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
cases <- list(c("window/drv/episodic_rule", 32.568059), c("window/drv/episodic_ruleB", 36.279452),
              c("phase1c/drv/episodic_ruleA_h26", 32.592593))
for (k in cases) {
  st <- readRDS(file.path(D, paste0(k[1], ".rds")))$st
  t <- as.numeric(k[2]); s <- st$time - st$h
  i <- which(s <= t & st$time >= t)
  cat(sprintf("%-32s raise at t = %.6f: in step %s; steps (start, days) %s\n", basename(k[1]), t,
              paste(i, collapse = "/"),
              paste(sprintf("(%.4f, %.2f)", s[max(1, min(i) - 2):max(i)], st$h[max(1, min(i) - 2):max(i)] * 365),
                    collapse = " ")))
}
