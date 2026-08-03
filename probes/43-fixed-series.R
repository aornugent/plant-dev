# Fixed-schedule convergence series: uniform bisection of the default schedule
# (141 -> 281 -> 561 -> 1121 -> ...), both coordinates.  Establishes whether a
# converged limit exists within reach for each arm, and supplies the Richardson
# extrapolation used as the accuracy reference in the eps sweep.
# Usage: Rscript 43-fixed-series.R MODEL KMAX
source("/home/user/plant-dev/probes/40-lib.R")
a <- commandArgs(TRUE)
model <- a[1]; kmax <- as.integer(a[2])
out <- sprintf("/home/user/plant-dev/probes/out/43-fixed-%s.rds", model)
res <- list()
for (k in 0:kmax) {
  for (bd in c(FALSE, TRUE)) {
    r <- tryCatch(run_fixed(model, bd, k),
                  error = function(e) data.frame(model = model, bd = bd, k = k,
                    n = NA, n_ode = NA, value = NA, secs = NA))
    res[[length(res) + 1]] <- r
    saveRDS(do.call(rbind, res), out)
    cat(sprintf("%-5s %-11s k=%d n=%-5d ode=%-6d val=%-15.10g %7.1fs\n",
                model, if (bd) "birth-date" else "height", k, r$n, r$n_ode,
                r$value, r$secs))
    flush.console()
  }
}
cat("DONE\n")
