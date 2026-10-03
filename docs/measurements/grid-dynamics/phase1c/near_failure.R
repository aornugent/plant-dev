# Episodic's steps around where lma x2's walk raised on rule A's program
# (t = 32.568) and on rule B's (t = 36.279): each program's steps there, in days.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
progs <- c(unweighted = "window/drv/episodic_base", "rule A" = "window/drv/episodic_rule",
           "rule B" = "window/drv/episodic_ruleB", "A, cap 15" = "phase1c/drv/episodic_ruleA_h15",
           "A, cap 20" = "phase1c/drv/episodic_ruleA_h20", "A, cap 22" = "phase1c/drv/episodic_ruleA_h22",
           "A, cap 26" = "phase1c/drv/episodic_ruleA_h26", "A thinned" = "window/drv/episodic_rule_thin",
           "A thinned, cap 15" = "phase1c/drv/episodic_ruleA_thin_h15")
for (t in c(32.568059, 36.279452)) {
  cat(sprintf("\nsteps (days) whose span touches [t - 60 d, t + 10 d] around t = %.3f\n", t))
  for (k in names(progs)) {
    f <- file.path(D, paste0(progs[[k]], ".rds"))
    if (!file.exists(f)) next
    st <- readRDS(f)$st
    s <- st$time - st$h
    i <- which(st$time >= t - 60 / 365 & s <= t + 10 / 365)
    cat(sprintf("%-18s %s\n", k, paste(sprintf("%.1f", st$h[i] * 365), collapse = " ")))
  }
}
cat("\nsteps over 15 and 26 days after t = 25, and the longest, per program\n")
for (k in names(progs)) {
  f <- file.path(D, paste0(progs[[k]], ".rds"))
  if (!file.exists(f)) next
  st <- readRDS(f)$st; late <- st$time - st$h > 25; hd <- st$h * 365
  cat(sprintf("%-18s %4d over 15 d, %3d over 26 d, longest %.1f d; steps after t = 25: %d\n", k,
              sum(hd[late] > 15 + 1e-9), sum(hd[late] > 26 + 1e-9), max(hd[late]), sum(late)))
}
