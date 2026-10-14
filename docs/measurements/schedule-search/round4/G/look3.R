# look3.R: where steps and rows are spent over patch age, a09's committed runs.
OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/G_out"
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
br <- c(0, 1, 2, 5, 10, 15, 20, 25, 30, 35, 40)
for (nm in c(list.files(AR, "^val_a09_c_.*rds$"), "val_a09s_c_long-drought.rds")) {
  x <- readRDS(file.path(AR, nm)); t <- x$stand$times; b <- x$node_times
  live <- findInterval(t, b)   # nodes born by t (approx rows per step: live nodes)
  st <- tapply(rep(1, length(t)), cut(t, br, right = FALSE), sum); rw <- tapply(live, cut(t, br, right = FALSE), sum)
  cat(sprintf("%-28s steps %5d rows~%7.0f (saved %7.0f) | steps%%: %s | rows%%: %s\n", sub("val_a09_c_|\\.rds", "", nm), length(t), sum(live), x$stand$rows,
    paste(sprintf("%2.0f", 100 * st / length(t)), collapse = " "), paste(sprintf("%2.0f", 100 * rw / sum(live)), collapse = " "))) }
cat("bands:", paste(head(br, -1), collapse = " "), "\n")
