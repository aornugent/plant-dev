O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/D_out/"
R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs/"
p <- readRDS(paste0(O, "e5_parsed.rds")); a <- p$a; b <- p$b
col <- "1.curv_fact_colim"; fin <- tail(b$g[, col], 1)
w <- function(x, lo, hi) { i <- which(x$d$t > lo & x$d$t < hi); inc <- diff(c(0, x$g[, col]))
  data.frame(x$d[i, ], cum = x$g[i, col], inc = inc[i]) }
print(w(a, 37.0, 37.12), digits = 8)
print(w(b, 37.0, 37.12), digits = 8)
s <- readRDS(paste0(R, "val_a10n1g_c_long-drought.rds"))
cat("nodes near:", s$node_times[s$node_times > 35 & s$node_times < 38], "\n")
cat("n nodes", length(s$node_times), "last", tail(s$node_times, 3), "\n")
