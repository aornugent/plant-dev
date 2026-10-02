# Where the daily values sit on the rain interpolant, and how the knots' rain
# changes classify by the daily values (analyse.R's view) against the
# interpolant over the day after the knot.
#   nice -n 10 Rscript DEV/rej_class/rain_index.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
W <- "/home/user/plant-dev/.claude/worktrees/agent-a4dae3c2572021890"
Sys.setenv(PLANT_LIB = file.path(D, "lib_v12t"))
source(file.path(W, "harness", "long_drought.R"))
env <- mkenv("long-drought")
rain_at <- function(t) pmax(0, env$extrinsic_drivers_evaluate_range("rainfall", t))
run <- readRDS(file.path(D, "pi/runs/pics_3e-5.rds"))
rain <- run$rain; DAY <- 1 / 365
i <- 30:45
cat("day index i, rain[i+1], interpolant at i/365, at (i+0.5)/365:\n")
print(cbind(i, value = rain[i + 1], at_knot = rain_at(i * DAY), mid_after = rain_at((i + 0.5) * DAY)))
knots <- sort(unique(run$knots))
ki <- round(knots / DAY)
stopifnot(all(abs(ki * DAY - knots) < 1e-12))
y_prev <- rain[ki]; y_here <- rain[ki + 1]; y_next <- rain[ki + 2]
daily <- ifelse(y_prev == 0 & y_here > 0, "starts", ifelse(y_prev > 0 & y_here == 0, "stops",
                ifelse(y_here > y_prev, "rises", "falls")))
after <- ifelse(y_here == 0 & y_next > 0, "starts", ifelse(y_here > 0 & y_next == 0, "stops",
                ifelse(y_next > y_here, "rises", ifelse(y_next < y_here, "falls", "flat"))))
cat("\nknots by the daily-value change (rows) and the interpolant over the day after (columns):\n")
print(table(daily, after))
