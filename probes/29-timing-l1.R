# Controlled A/B timing.  Earlier reports claimed dropping the perturbation
# roughly halves runtime; this measures it with nothing else on the machine,
# three repeats per arm, and separates the two contributions: the accepted step
# count (deterministic) and the cost per step (one rate evaluation per cohort per
# Runge-Kutta stage instead of two).
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
midpoints <- function(tt) sort(unique(c(tt, (head(tt,-1)+tail(tt,-1))/2)))
p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
REPS <- 3
for (lev in 1:1) {
  tt <- p0$node_schedule_times[[1]]
  if (lev > 0) tt <- midpoints(tt)
  p <- p0; p$node_schedule_times <- list(tt)
  out <- list()
  for (bd in c(FALSE, TRUE)) {
    ct <- Control(); ct$node_density_in_birth_date <- bd
    tms <- numeric(REPS); steps <- NA
    for (k in seq_len(REPS)) {
      t0 <- proc.time()[["elapsed"]]
      scm <- run_scm(p, Environment("TF24"), ct, collect = FALSE, refine_schedule = FALSE)
      tms[k] <- proc.time()[["elapsed"]] - t0
      steps <- length(scm$ode_times)
    }
    out[[as.character(bd)]] <- list(t = tms, steps = steps)
    cat(sprintf("n=%-4d %-11s median=%6.1fs  (reps: %s)  accepted steps=%d\n",
        length(tt), if (bd) "birth-date" else "height", median(tms),
        paste(sprintf("%.1f", tms), collapse=", "), steps)); flush.console()
  }
  h <- out[["FALSE"]]; b <- out[["TRUE"]]
  cat(sprintf("       speedup = %.2fx   of which step-count %.2fx and per-step %.2fx\n",
      median(h$t)/median(b$t), h$steps/b$steps,
      (median(h$t)/h$steps)/(median(b$t)/b$steps)))
  flush.console()
}
