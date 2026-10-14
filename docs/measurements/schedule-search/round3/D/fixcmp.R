suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/D_out/"
R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs/"
rd <- function(n) { f <- if (file.exists(paste0(O, n, ".rds"))) paste0(O, n, ".rds") else paste0(R, n, "_long-drought.rds"); readRDS(f) }
nm <- commandArgs(TRUE)
ref <- reference("long-drought")
Q <- sapply(nm, function(n) { q <- quantities(rd(n)); k <- names(ref); (q[k] - ref[k]) / eps_vec(k) })
st <- sapply(nm, function(n) { x <- rd(n); c(J = x$stand$J, steps = length(x$stand$times), fwd = x$stand$cpu, sweep = if (is.null(x$sweep_cpu)) NA else x$sweep_cpu, maxel = max(abs(x$stand$elasticity))) })
options(width = 220); print(round(st, 4))
cat("\n(q - reference)/eps, worst 12 rows by spread across runs:\n")
o <- order(-apply(Q, 1, function(r) diff(range(r, na.rm = TRUE))))
print(round(Q[o[1:12], ], 3))
cat("\nmax pairwise spread over all quantities (eps):", round(max(apply(Q, 1, function(r) diff(range(r)))), 3), "\n")
