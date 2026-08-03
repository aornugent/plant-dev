# Check the R-driven refinement loop reproduces SCM::refine_schedule() exactly,
# on the two cheap models, in both coordinates.
source("/home/user/plant-dev/probes/40-lib.R")
for (model in c("K93", "FF16")) {
  for (bd in c(FALSE, TRUE)) {
    eps <- 0.02
    scm <- make_scm(model, bd, eps)
    t0 <- Sys.time(); scm$refine_schedule()
    cpp <- list(n = length(scm$parameters$node_schedule_times[[1]]),
                v = scm$offspring_production[[1]],
                ode = length(scm$ode_times),
                t = as.numeric(difftime(Sys.time(), t0, units = "secs")))
    r <- refine_traced(model, bd, eps, verbose = FALSE)
    last <- r$rows[nrow(r$rows), ]
    # C++ installs parameters.node_schedule_times from node_schedule AFTER the
    # loop: equal to the schedule just run when it converged, and to the
    # bisected (never-run) schedule when nsteps was exhausted.
    n_final <- if (isTRUE(r$converged)) last$n_run else
      length(bisect_flagged(r$final$times, !is.na(r$final$err) & is.finite(r$final$err) & r$final$err > eps))
    cat(sprintf("%-5s %-11s C++ n=%-5d v=%-12.8g ode=%-6d %5.1fs | R n=%-5d v=%-12.8g ode=%-6d iters=%-3d conv=%-5s %5.1fs | match n:%s v:%s\n",
                model, if (bd) "birth-date" else "height",
                cpp$n, cpp$v, cpp$ode, cpp$t,
                n_final, last$value, last$n_ode, nrow(r$rows), r$converged, r$total_s,
                identical(as.integer(cpp$n), as.integer(n_final)),
                isTRUE(all.equal(cpp$v, last$value))))
    flush.console()
  }
}
