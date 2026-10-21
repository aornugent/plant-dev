# Cost of keeping the rows: MODE=off sweeps through stand_gradient, MODE=on
# through stand_adjoint_rows; one process per mode so VmHWM is each one's own.
source(file.path(Sys.getenv("CHECKS"), "fixture.R"))
mode <- Sys.getenv("MODE")
sweep <- function(scm, metric) {
  if (mode == "on") stand_adjoint_rows(scm, metric) else stand_gradient(scm, metrics = metric)
}
gc(); t_run <- system.time(res <- fixture_run())[["elapsed"]]
rec <- res$store_trajectory()
n_state <- sum(vapply(rec, function(x) length(x$state), 1L)); rm(rec); gc()
h_run <- vmhwm()
ts <- replicate(3, system.time(x <- sweep(res, "1.offspring_production"))[["elapsed"]])
h_res <- vmhwm()
rm(x); gc()
res$record_trajectory <- TRUE
t_inv <- system.time(res$run_mutant(fixture_parameters(1)))[["elapsed"]]
h_inv_run <- vmhwm()
ti <- replicate(3, system.time(x <- sweep(res, "1.net_reproduction_ratio"))[["elapsed"]])
h_inv <- vmhwm()
cat(sprintf("%s LIFETIME %g NODES %d: run %.1f s, %d recorded state doubles (%.1f MB); resident sweeps %s s; VmHWM run %.0f -> sweeps %.0f MB; invader run %.1f s, sweeps %s s; VmHWM %.0f -> %.0f MB\n",
            mode, LIFETIME, NODES, t_run, n_state, n_state * 8 / 2^20,
            paste(sprintf("%.1f", ts), collapse = " "), h_run, h_res, t_inv,
            paste(sprintf("%.1f", ti), collapse = " "), h_inv_run, h_inv))
