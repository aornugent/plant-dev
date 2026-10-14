# cmp.R NAME BASE CASE: an E run against the saved run it varies (BASE, a file under
# adjmap/runs) and against the case's reference: move and error in ε, rows, CPU.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max")
a <- commandArgs(TRUE); EO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/E_out"
x <- readRDS(file.path(EO, "runs", paste0(a[1], ".rds"))); b <- readRDS(if (file.exists(a[2])) a[2] else file.path(AR, a[2])); case <- a[3]
refq <- function(case) if (!is.null(CASES[[case]])) reference(case) else {
  u <- quantities(readRDS(file.path(AR, sprintf("ref_%s_u215.rds", case)))); v <- quantities(readRDS(file.path(AR, sprintf("ref_%s_u429.rds", case))))
  k <- intersect(names(u), names(v)); extrap(u[k], v[k]) }
ref <- refq(case); qx <- quantities(x); qb <- quantities(b); k <- Reduce(intersect, list(names(ref), names(qx), names(qb))); e <- eps_vec(k)
mv <- (qx[k] - qb[k]) / e; ex <- (qx[k] - ref[k]) / e; eb <- (qb[k] - ref[k]) / e
o <- order(-abs(mv))[1:6]
cat(sprintf("%s vs %s: rows %.0f / %.0f = %.3f | steps %d / %d | cpu fwd %.0f / %.0f, sweep %.0f / %.0f, total ratio %.3f\n", a[1], a[2], x$stand$rows, b$stand$rows,
  x$stand$rows / b$stand$rows, length(x$stand$times), length(b$stand$times), x$stand$cpu, b$stand$cpu, x$sweep_cpu, b$sweep_cpu, (x$stand$cpu + x$sweep_cpu) / (b$stand$cpu + b$sweep_cpu)))
cat(sprintf("  move: max %.3f ε (%s), rms %.3f | error: worst %.3f (base %.3f), rms %.3f (base %.3f) | max |el| %.1f (base %.1f)%s\n", max(abs(mv)), k[which.max(abs(mv))],
  sqrt(mean(mv^2)), max(abs(ex)), max(abs(eb)), sqrt(mean(ex^2)), sqrt(mean(eb^2)), max(abs(x$stand$elasticity)), max(abs(b$stand$elasticity)),
  if (!is.null(x$refusal) && length(x$refusal) && any(nzchar(unlist(x$refusal)))) " REFUSAL" else ""))
cat("  top moves:", paste(sprintf("%s %+.3f (err %+.2f -> %+.2f)", k[o], mv[o], eb[o], ex[o]), collapse = "; "), "\n")
if (!is.null(x$attempts)) cat("  attempts:", x$attempts, "\n")
