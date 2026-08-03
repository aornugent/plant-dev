# Control sweep: FF16 (growth a function of size alone, so both coordinates
# must agree) and K93, across the same schedule_eps decades.
source("/home/user/plant-dev/probes/40-lib.R")
a <- commandArgs(TRUE); model <- a[1]
eps_list <- c(0.2, 0.0632, 0.02, 0.00632, 0.002, 0.000632, 0.0002)
out <- sprintf("/home/user/plant-dev/probes/out/44-%s.rds", model)
res <- list()
for (bd in c(FALSE, TRUE)) for (eps in eps_list) {
  r <- refine_traced(model, bd, eps, nsteps = 20, verbose = FALSE)
  last <- r$rows[nrow(r$rows), ]
  flag <- if (is.null(r$final)) NA else !is.na(r$final$err) & is.finite(r$final$err) & r$final$err > eps
  n_final <- if (isTRUE(r$converged)) last$n_run else length(bisect_flagged(r$final$times, flag))
  res[[length(res)+1]] <- list(model=model, bd=bd, eps=eps, iters=nrow(r$rows),
    converged=r$converged, n_run=last$n_run, n_final=n_final, n_ode=last$n_ode,
    value=last$value, n_flag=sum(flag), total_s=r$total_s, trace=r$rows, final=r$final)
  saveRDS(res, out)
  cat(sprintf("%-5s %-3s eps=%-9.3g iters=%-3d conv=%-5s n_run=%-5d n_final=%-5d ode=%-6d val=%-15.10g %7.1fs\n",
              model, if (bd) "bd" else "ht", eps, nrow(r$rows), r$converged,
              last$n_run, n_final, last$n_ode, last$value, r$total_s))
  flush.console()
}
cat("DONE\n")
