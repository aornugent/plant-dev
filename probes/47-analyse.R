# Assemble the Pareto tables from the eps sweeps and the fixed-schedule series.
source("/home/user/plant-dev/probes/40-lib.R")

# Work proxy that needs no timing: the number of node-evaluations the solver
# performs, i.e. sum over accepted ODE steps of the live node count.  (An RKCK
# step costs 6 rate evaluations over every live node; the deleted
# growth_rate_gradient is also per node per stage, so the height arm's constant
# is larger by the measured per-step factor.)
node_steps <- function(sched, ode_times) sum(findInterval(ode_times, sched))

load_sweep <- function(f) {
  if (!file.exists(f)) return(NULL)
  res <- readRDS(f)
  do.call(rbind, lapply(res, function(r) {
    ns <- if (!is.null(r$final)) node_steps(r$final$times, r$final$ode_times) else NA
    data.frame(model = r$model, arm = if (r$bd) "birth-date" else "height",
               eps = r$eps, iters = r$iters, converged = r$converged,
               n = r$n_run, n_final = r$n_final, steps = r$n_ode,
               node_steps = ns, value = r$value, secs = r$total_s)
  }))
}

fmt <- function(d, limit, psf) {
  d$relerr <- abs(d$value - limit) / abs(limit)
  d$cost_steps <- d$steps * psf
  d$cost_nodesteps <- d$node_steps * psf
  d
}

files <- c(list.files("/home/user/plant-dev/probes/out", "^42-eps-.*rds$", full.names = TRUE),
           list.files("/home/user/plant-dev/probes/out", "^44-.*rds$", full.names = TRUE))
all <- do.call(rbind, lapply(files, load_sweep))
print(all, digits = 10)
cat("\n=== fixed-schedule series ===\n")
for (f in list.files("/home/user/plant-dev/probes/out", "^43-fixed-.*rds$", full.names = TRUE)) {
  d <- readRDS(f); d$arm <- ifelse(d$bd, "birth-date", "height")
  for (a in unique(d$arm)) {
    s <- d[d$arm == a, ]
    s <- s[order(s$k), ]
    dif <- c(NA, diff(s$value))
    rat <- c(NA, dif[-1] / dif[-length(dif)])
    p <- -log2(rat)
    rich <- s$value + dif / (2^p - 1)
    print(data.frame(model = s$model, arm = a, k = s$k, n = s$n, steps = s$n_ode,
                     value = s$value, diff = dif, ratio = rat, order_p = p,
                     richardson = rich), digits = 10)
  }
}
saveRDS(all, "/home/user/plant-dev/probes/out/47-pareto-raw.rds")
