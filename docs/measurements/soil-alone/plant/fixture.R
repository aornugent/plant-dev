suppressMessages(library(plant))
life <- as.numeric(Sys.getenv("LIFE", "1"))
p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- life
p0$patch_type <- "fixed"
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
env <- function() { e <- Environment("TF24"); e$extrinsic_drivers_set_constant("rainfall", 3); e }
ctrl <- function(share, tol) {
  x <- control_tf24(tol, Control(node_density_in_birth_date = TRUE, ode_split_sign_changes = TRUE))
  x$ode_soil_alone_share <- share
  x
}
J <- function(share, tol) {
  t0 <- proc.time()[[3]]
  r <- run_scm(p, env(), ctrl(share, tol))
  c(J = sum(r$offspring_production), steps = length(r$ode_times) - 1, s = proc.time()[[3]] - t0)
}
ref <- J(0, 1e-9)
cat(sprintf("life %g: reference J %.15e (%d steps, %.1fs)\n", life, ref[1], ref[2], ref[3]))
for (tol in c(1e-4, 3e-5, 1e-5, 1e-6)) for (share in c(0, 0.1)) {
  x <- J(share, tol)
  cat(sprintf("tol %.0e share %.1f: steps %4d  rel err %+.3e  (%.1fs)\n", tol, share, x[2], x[1] / ref[1] - 1, x[3]))
}
