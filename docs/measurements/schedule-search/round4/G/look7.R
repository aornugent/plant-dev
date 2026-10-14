# look7.R: on a09's runs in the proper setting (a09p for the long-drought records), the rows
# in steps that end on a rainfall knot, by age band, and the share of rows after b = 25, 30.
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
suppressMessages(source("/home/user/plant-dev/harness/long_drought.R"))
br <- c(0, 2, 5, 10, 20, 25, 30, 35, 40)
kn <- function(x) { reg <- x$setting$regime; seed <- x$setting$seed; scen <- sprintf("%s, seed %d", reg, seed)
  RAIN_SPECS[[scen]] <<- modifyList(RAIN_SPECS[[reg]], list(seed = seed)); active_knots(scen) }
tot <- NULL
for (cs in c("episodic", "dry", "long-wet", "long-drought", "episodic-lma", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")) for (cf in c("c", "f")) {
  tag <- if (grepl("ld|long-drought", cs)) "a09p" else "a09"; x <- readRDS(file.path(AR, sprintf("val_%s_%s_%s.rds", tag, cf, cs)))
  k <- kn(x); t <- x$stand$times; te <- t[-1]; live <- findInterval(t[-length(t)], x$node_times, left.open = FALSE) + 1
  onk <- vapply(te, function(s) min(abs(k - s)) < 1e-9, TRUE); bd <- cut(te, br, right = FALSE)
  late <- te >= 25; r <- sum(live)
  # a late step that ends on a knot and starts within 1.01 d of one: a knot-to-knot day
  st <- t[-length(t)]; stk <- c(TRUE, onk[-length(onk)])
  kk <- onk & stk
  row <- data.frame(case = cs, cf = cf, steps = length(te), knot_steps = mean(onk), knot_rows = sum(live[onk]) / r,
    rows25 = sum(live[late]) / r, rows30 = sum(live[te >= 30]) / r, knot_rows25 = sum(live[onk & late]) / r, kk_rows25 = sum(live[kk & late]) / r,
    steps_yr25 = sum(late) / (40 - 25), cpu = x$stand$cpu, sweep = x$sweep_cpu)
  tot <- rbind(tot, row) }
print(format(tot, digits = 2), row.names = FALSE)
saveRDS(tot, "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/G_out/knot_rows.rds")
