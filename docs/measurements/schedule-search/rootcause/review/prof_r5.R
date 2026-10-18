suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
R5 <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence/r5/runs"
f <- function(x) c(nodes=length(x$node_times), steps=length(x$stand$times), rows=x$stand$rows, fwd=x$stand$cpu, sweep=x$sweep_cpu)
out <- NULL
for (cs in c("dry","long-wet","episodic-lma","dry-flat","epi-adG208")) {
  for (k in c("G5","G5o","G5b")) { x <- readRDS(file.path(R5, sprintf("%s_%s.rds", k, cs))); out <- rbind(out, data.frame(case=cs, run=k, t(f(x)))) }
  e6 <- tryCatch(e6_runs(cs), error=function(e) NULL)
  if (!is.null(e6)) { out <- rbind(out, data.frame(case=cs, run="E6c", t(f(e6$x0)))); out <- rbind(out, data.frame(case=cs, run="E6f", t(f(e6$x1)))) }
}
out$cpu <- out$fwd + out$sweep; out$sweep_share <- out$sweep/out$cpu; out$us_per_row_fwd <- 1e6*out$fwd/out$rows; out$us_per_row_sw <- 1e6*out$sweep/out$rows
options(width=200); print(format(out, digits=3))
str(readRDS(file.path(R5,"G5_dry.rds"))$stand$nodes, max.level=1)
