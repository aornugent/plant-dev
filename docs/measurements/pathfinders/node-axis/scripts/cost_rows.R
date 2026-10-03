# Each node-axis run's CPU per row by phase (rows: members alive at each accepted step's
# start), and its peak memory, for one record.
#   Rscript cost_rows.R long-wet|long-drought
N <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pf_nodes"
short <- c("long-wet" = "wet", "long-drought" = "ld")[[commandArgs(TRUE)[1]]]
rows_of <- function(x) {
  b <- sort(x$stand$nodes$birth)
  sum(findInterval(x$stand$times[-1] - x$stand$sizes[-1], b))
}
runs <- c("L_u54", "L_u215", "B_G1", "B_G2", "B_G3", "D_u54", "D_u108", "D_u215", "D_u429",
          "BD_G1", "BD_G2", "BD_G3")
cat(sprintf("%-9s %8s | us per row: %7s %11s %12s %13s | %7s\n", "run", "rows", "forward", "stand sweep",
            "invader walk", "invader sweep", "peak MB"))
for (n in runs) {
  f <- file.path(N, "runs", sprintf("%s_%s.rds", short, n))
  if (!file.exists(f)) next
  x <- readRDS(f)
  if (is.null(x$finished) || is.null(x$phases$invader_gradient)) next
  r <- rows_of(x); p <- x$phases
  cat(sprintf("%-9s %8.0f | %19.1f %11.1f %12.1f %13.1f | %7.0f\n", n, r, 1e6 * p$stand_run$cpu / r,
              1e6 * p$stand_gradient$cpu / r, 1e6 * p$invader_run$cpu / r, 1e6 * p$invader_gradient$cpu / r,
              max(vapply(p, function(q) q$peak_mb, 0))))
}
