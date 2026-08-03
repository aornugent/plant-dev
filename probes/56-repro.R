# The Part-1 sweep and the Part-3 timing disagree on the same 204-node schedule
# (6233 steps / 60.3519 vs 6110 / 60.1972).  Is a run reproducible within one
# process, and does prior run history change it?
source("/home/user/plant-dev/probes/40-lib.R")
sched_for <- function(bd, eps) {
  f <- sprintf("/home/user/plant-dev/probes/out/42-eps-TF24-%s.rds", if (bd) "bd" else "ht")
  for (r in readRDS(f)) if (identical(r$bd, bd) && isTRUE(all.equal(r$eps, eps))) return(r$final$times)
}
for (bd in c(FALSE, TRUE)) {
  tt <- sched_for(bd, 0.02); d0 <- node_schedule_times_default(max(tt))
  scm <- make_scm("TF24", bd)
  # run A: the target schedule from a fresh SCM
  scm$reset(); scm$set_node_schedule_times(list(tt)); scm$run()
  cat(sprintf("%s A fresh      n=%d steps=%d val=%.10g\n", if (bd) "bd" else "ht",
              length(tt), length(scm$ode_times), scm$offspring_production[[1]]))
  # run B: same schedule again in the same object
  scm$reset(); scm$set_node_schedule_times(list(tt)); scm$run()
  cat(sprintf("%s B repeat     n=%d steps=%d val=%.10g\n", if (bd) "bd" else "ht",
              length(tt), length(scm$ode_times), scm$offspring_production[[1]]))
  # run C: after an intervening run on the default schedule
  scm$reset(); scm$set_node_schedule_times(list(d0)); scm$run()
  scm$reset(); scm$set_node_schedule_times(list(tt)); scm$run()
  cat(sprintf("%s C after other n=%d steps=%d val=%.10g\n", if (bd) "bd" else "ht",
              length(tt), length(scm$ode_times), scm$offspring_production[[1]]))
  flush.console()
}
cat("DONE\n")
