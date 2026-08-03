# Part 3: clean wall-clock confirmation of the cost proxy.  Re-runs the refined
# schedules from the Part-1 sweep as fixed schedules, so the measurement is the
# single SCM run that the cost proxy predicts.  Refuses to start unless idle.
source("/home/user/plant-dev/probes/40-lib.R")
node_steps <- function(sched, ode) sum(findInterval(ode, sched))
busy <- function() as.integer(system("ps -eo cmd | grep -c '[e]xec/R'", intern = TRUE))
if (busy() > 1) stop("machine not idle: ", busy(), " R processes")

sched_for <- function(model, bd, eps) {
  f <- sprintf("/home/user/plant-dev/probes/out/42-eps-%s-%s.rds", model, if (bd) "bd" else "ht")
  for (r in readRDS(f)) if (identical(r$bd, bd) && isTRUE(all.equal(r$eps, eps))) return(r$final$times)
  stop("no saved schedule")
}
cfg <- list(list(bd = FALSE, eps = 0.02), list(bd = TRUE, eps = 0.02), list(bd = TRUE, eps = 0.2))
out <- list()
for (i in 1:3) for (k in seq_along(cfg)) {
  cf <- cfg[[k]]; tt <- sched_for("TF24", cf$bd, cf$eps)
  scm <- make_scm("TF24", cf$bd); scm$reset(); scm$set_node_schedule_times(list(tt)); gc()
  t0 <- Sys.time(); scm$run()
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  out[[length(out)+1]] <- data.frame(arm = if (cf$bd) "birth-date" else "height", eps = cf$eps,
    rep = i, n = length(tt), steps = length(scm$ode_times),
    node_steps = node_steps(tt, scm$ode_times), value = scm$offspring_production[[1]],
    secs = secs, busy = busy())
  cat(sprintf("%-11s eps=%-7g rep=%d n=%-4d steps=%-6d node_steps=%-9d val=%-14.9g %8.2fs (busy=%d)\n",
    if (cf$bd) "birth-date" else "height", cf$eps, i, length(tt), length(scm$ode_times),
    node_steps(tt, scm$ode_times), scm$offspring_production[[1]], secs, busy()))
  flush.console(); saveRDS(do.call(rbind, out), "/home/user/plant-dev/probes/out/55-timing.rds")
}
d <- do.call(rbind, out)
cat("\n--- medians (3 repeats) ---\n")
m <- aggregate(secs ~ arm + eps + n + steps + node_steps, d, median)
m$s_per_nodestep <- m$secs / m$node_steps
print(m, digits = 6)
cat("DONE\n")
