# Where a run's soil error sits: at each common time with the tight recording, the
# largest layer error, split by whether the interval ending there was raining, and
# by time since the last rain onset.
#   Rscript where_soil.R run.rds ...
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
ref <- readRDS(file.path(D, "partition_bias/out/rec_1e-7.rds"))
for (f in commandArgs(TRUE)) {
  r <- readRDS(f)
  st <- r$st
  i <- match(st$time, ref$time); ok <- which(!is.na(i))
  d <- apply(abs(as.matrix(st[ok, paste0("soil_", 1:5)]) - ref$soil[i[ok], ]), 1, max)
  lay <- apply(abs(as.matrix(st[ok, paste0("soil_", 1:5)]) - ref$soil[i[ok], ]), 1, which.max)
  # the rain over the day before each common time, from the record (daily values)
  day <- pmax(1, ceiling(st$time[ok] * 365))
  rain_day <- r$rain[pmin(day, length(r$rain))]
  wet <- rain_day > 0
  q <- function(x) sprintf("median %.2e, 90%% %.2e, max %.2e", median(x), quantile(x, 0.9), max(x))
  cat(sprintf("%s (%d accepted): soil error at %d common times\n", basename(f), nrow(st), length(ok)))
  cat(sprintf("  on wet days (%d): %s\n  on dry days (%d): %s\n", sum(wet), q(d[wet]), sum(!wet), q(d[!wet])))
  cat(sprintf("  the layer with the largest error, counts 1-5: %s\n", paste(tabulate(lay, 5), collapse = "/")))
  # steps per wet and dry day
  sday <- pmax(1, ceiling((st$time - st$h / 2) * 365))
  swet <- r$rain[pmin(sday, length(r$rain))] > 0
  cat(sprintf("  accepted steps on wet days %d, on dry days %d\n", sum(swet), sum(!swet)))
}
