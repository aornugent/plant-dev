# fr_tol.R: what a looser tolerance buys, from the refine round's same-schedule pairs at 1e-4 and
# 3e-5 (episodic-lma, libS): rows, steps and CPU ratios, and the quantities' move between them.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
fs <- list.files(file.path(RO, "runs"), "^rf_episodic-lma_1e-04_")
for (f in fs) { a <- readRDS(file.path(RO, "runs", f)); b <- RF_RUN(sub("1e-04", "3e-05", sub("\\.rds$", "", f)))
  if (is.null(b) || is.null(a$stand$elasticity) || is.null(b$stand$elasticity)) next
  mv <- (qv(a) - qv(b)) / EPS
  cat(sprintf("%-40s nodes %d  rows 1e-4/3e-5 %.3f  steps %.3f  cpu %.3f  move max %.3f (%s) rms %.3f\n", f, length(a$node_times),
    a$stand$rows / b$stand$rows, length(a$stand$times) / length(b$stand$times), (a$stand$cpu + a$sweep_cpu) / (b$stand$cpu + b$sweep_cpu), max(abs(mv)), names(mv)[which.max(abs(mv))], sqrt(mean(mv^2)))) }
