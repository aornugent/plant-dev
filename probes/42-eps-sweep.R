# The accuracy/cost Pareto curve: sweep schedule_eps in both coordinates.
# Usage: Rscript 42-eps-sweep.R MODEL BD EPSLIST [BUDGET_S]
#   MODEL in K93/FF16/TF24, BD in 0/1, EPSLIST comma-separated, loose first.
source("/home/user/plant-dev/probes/40-lib.R")
a <- commandArgs(TRUE)
model <- a[1]; bd <- as.logical(as.integer(a[2]))
eps_list <- as.numeric(strsplit(a[3], ",")[[1]])
budget <- if (length(a) >= 4) as.numeric(a[4]) else Inf
tag <- sprintf("%s-%s", model, if (bd) "bd" else "ht")
out <- sprintf("/home/user/plant-dev/probes/out/42-eps-%s.rds", tag)

res <- list()
for (eps in eps_list) {
  cat(sprintf("=== %s eps=%g ===\n", tag, eps)); flush.console()
  r <- refine_traced(model, bd, eps, nsteps = 20, budget_s = budget)
  last <- r$rows[nrow(r$rows), ]
  flag_final <- if (is.null(r$final)) NA else
    sum(!is.na(r$final$err) & is.finite(r$final$err) & r$final$err > eps)
  n_final <- if (isTRUE(r$converged)) last$n_run else if (is.null(r$final)) NA else
    length(bisect_flagged(r$final$times, !is.na(r$final$err) & is.finite(r$final$err) & r$final$err > eps))
  res[[length(res) + 1]] <- list(
    model = model, bd = bd, eps = eps, iters = nrow(r$rows),
    converged = r$converged, n_run = last$n_run, n_final = n_final,
    n_ode = last$n_ode, value = last$value, n_flag = flag_final,
    total_s = r$total_s, trace = r$rows, final = r$final)
  saveRDS(res, out)
  cat(sprintf("--> %s eps=%-9.3g iters=%-3d conv=%-5s n_run=%-5d n_final=%-5d ode=%-6d val=%-14.9g  %7.1fs\n",
              tag, eps, nrow(r$rows), r$converged, last$n_run, n_final,
              last$n_ode, last$value, r$total_s))
  flush.console()
}
cat("DONE\n")
