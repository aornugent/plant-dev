# nudge.R A B [A B ...]: a tolerance nudge's move (B - A) in eps over the scored
# quantities, plus each run's steps, rows and CPU. Looks in JT_out, X_out, P_out, AG_out.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R"))
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
rd <- function(n) { for (d in c("JT_out", "X_out/runs", "P_out/runs", "AG_out/runs")) { f <- file.path(S, d, paste0(n, ".rds")); if (file.exists(f)) return(readRDS(f)) }; stop(n) }
a <- commandArgs(TRUE)
for (i in seq(1, length(a), 2)) { x <- rd(a[i]); y <- rd(a[i + 1]); qx <- quantities(x); qy <- quantities(y); k <- intersect(names(qx), names(qy)); d <- (qy[k] - qx[k]) / eps_vec(k)
  cat(sprintf("%s -> %s: rms %.4f max %.3f (%s), TF24_cost_scale %+.3f | steps %d / %d, rows %.0f / %.0f, cpu %.0f+%.0f / %.0f+%.0f\n", a[i], a[i + 1],
    sqrt(mean(d^2)), max(abs(d)), k[which.max(abs(d))], d[grep("TF24_cost_scale", k)[1]], length(x$stand$times), length(y$stand$times),
    x$stand$rows, y$stand$rows, x$stand$cpu, x$sweep_cpu, y$stand$cpu, y$sweep_cpu)) }
