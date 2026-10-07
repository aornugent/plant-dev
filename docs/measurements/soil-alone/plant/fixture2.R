suppressMessages(library(plant))
p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 1
p0$patch_type <- "fixed"
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
env <- function(dim) {
  e <- Environment("TF24")
  e$extrinsic_drivers_set_constant("rainfall", 3)
  if (dim) {
    t <- seq(0, 1, length.out = 200)
    e$extrinsic_drivers_set_variable("PPFD", t, e$extrinsic_drivers_evaluate("PPFD", 0) * (1 + 0.9 * sin(2 * pi * t)))
  }
  e
}
ctrl <- function(share, tol) {
  x <- control_tf24(tol, Control(node_density_in_birth_date = TRUE, ode_split_sign_changes = TRUE))
  x$ode_soil_alone_share <- share
  x
}
for (dim in c(FALSE, TRUE)) {
  ref <- run_scm(p, env(dim), ctrl(0, 1e-7))
  for (share in c(0, 0.1)) {
    t0 <- proc.time()[[3]]
    r <- run_scm(p, env(dim), ctrl(share, 1e-4), record_trajectory = TRUE)
    cat(sprintf("dim %d share %.1f: steps %d splits %d rel err %+.2e (ref %d steps)  %.1fs\n", dim, share,
                length(r$ode_times) - 1, sum(r$ode_splits), sum(r$offspring_production) / sum(ref$offspring_production) - 1,
                length(ref$ode_times) - 1, proc.time()[[3]] - t0))
  }
}
