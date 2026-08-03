# Part 3: clean wall-clock confirmation of the cost proxy, at the operating
# points chosen in Part 1.  Refuses to run unless the machine is idle.
# Usage: Rscript 51-timing.R MODEL "n_ht_eps,n_bd_eps" REPS
#   the two eps values name the adaptive operating points to reproduce; the
#   refined schedule is taken from the saved sweep and re-run as a fixed
#   schedule, so the timing measures the run the cost proxy predicts.
source("/home/user/plant-dev/probes/40-lib.R")
a <- commandArgs(TRUE)
model <- a[1]; eps2 <- as.numeric(strsplit(a[2], ",")[[1]]); reps <- as.integer(a[3])
node_steps <- function(sched, ode) sum(findInterval(ode, sched))

busy <- function() as.integer(system("ps -eo cmd | grep -c '[e]xec/R'", intern = TRUE))
if (busy() > 1) stop("machine not idle: ", busy(), " R processes")

sched_for <- function(model, bd, eps) {
  f <- sprintf("/home/user/plant-dev/probes/out/42-eps-%s-%s.rds", model, if (bd) "bd" else "ht")
  if (!file.exists(f)) f <- sprintf("/home/user/plant-dev/probes/out/44-%s.rds", model)
  for (r in readRDS(f)) if (identical(r$bd, bd) && isTRUE(all.equal(r$eps, eps))) return(r$final$times)
  stop("no saved schedule for ", model, " bd=", bd, " eps=", eps)
}

out <- list()
for (i in seq_len(reps)) {
  for (j in 1:2) {
    bd <- (j == 2); eps <- eps2[j]
    tt <- sched_for(model, bd, eps)
    scm <- make_scm(model, bd)
    scm$reset(); scm$set_node_schedule_times(list(tt))
    gc()
    t0 <- Sys.time(); scm$run()
    secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    ns <- node_steps(tt, scm$ode_times)
    out[[length(out) + 1]] <- data.frame(model = model, arm = if (bd) "birth-date" else "height",
      eps = eps, rep = i, n = length(tt), steps = length(scm$ode_times), node_steps = ns,
      value = scm$offspring_production[[1]], secs = secs, busy = busy())
    cat(sprintf("%-5s %-11s eps=%-9.3g rep=%d n=%-5d steps=%-6d node_steps=%-9d val=%-14.9g %8.2fs (busy=%d)\n",
                model, if (bd) "bd" else "ht", eps, i, length(tt), length(scm$ode_times), ns,
                scm$offspring_production[[1]], secs, busy()))
    flush.console()
    saveRDS(do.call(rbind, out), sprintf("/home/user/plant-dev/probes/out/51-timing-%s.rds", model))
  }
}
d <- do.call(rbind, out)
cat("\n--- medians ---\n")
print(aggregate(cbind(secs, steps, node_steps) ~ arm + n, d, median), digits = 6)
cat("DONE\n")
