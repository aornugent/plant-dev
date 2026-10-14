# look5.R: how many accepted steps end on a rainfall knot (a forced stop), by patch age.
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
suppressMessages(source("/home/user/plant-dev/harness/long_drought.R"))
br <- c(0, 2, 5, 10, 20, 25, 30, 35, 40)
for (cs in c("dry", "episodic", "long-wet", "dry-flat", "ld-102", "long-drought")) {
  x <- readRDS(file.path(AR, sprintf("val_a09_c_%s.rds", cs))); reg <- x$setting$regime; seed <- x$setting$seed
  scen <- sprintf("%s, seed %d", reg, seed); RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[reg]], list(seed = seed))
  k <- active_knots(scen); t <- x$stand$times; te <- t[-1]
  onk <- vapply(te, function(s) min(abs(k - s)) < 1e-9, TRUE); onn <- vapply(te, function(s) min(abs(x$node_times - s)) < 1e-9, TRUE)
  bd <- cut(te, br, right = FALSE); live <- findInterval(t[-length(t)], x$node_times) + 1
  cat(sprintf("%-13s knots in [0,40): %5d (%.0f/yr)  steps %5d  ending on knot %.2f (rows %.2f), on a node %.2f, share '%s'\n", cs, length(k), length(k) / 40, length(te), mean(onk),
    sum(live[onk]) / sum(live), mean(onn), x$setting$env["SHARE"]))
  cat("   on knot by band: ", sprintf("%.2f", tapply(onk, bd, mean)), "\n")
  cat("   knots/step band: ", sprintf("%.2f", tapply(k, cut(k, br, right = FALSE), length) / tapply(te, bd, length)), "\n") }
