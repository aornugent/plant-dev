suppressMessages(library(plant))
p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 3
p0$patch_type <- "fixed"
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
env <- function() {
  e <- Environment("TF24")
  t <- seq(0, 3, length.out = 601)
  e$extrinsic_drivers_set_variable("rainfall", t, 0.25 * (1 + 0.95 * sin(2 * pi * t)))
  e
}
ctrl <- function(share, tol = 1e-4, split = TRUE) {
  x <- control_tf24(tol, Control(node_density_in_birth_date = TRUE, ode_split_sign_changes = split))
  x$ode_soil_alone_share <- share
  x
}
for (tol in c(1e-4, 1e-5, 1e-7)) for (share in c(0, 0.1)) {
  t0 <- proc.time()[[3]]
  r <- tryCatch(run_scm(p, env(), ctrl(share, tol)), error = function(e) conditionMessage(e))
  if (is.character(r)) { cat(sprintf("tol %.0e share %.1f: ERROR %s\n", tol, share, r)); next }
  a <- r$ode_step_attempts
  cat(sprintf("tol %.0e share %.1f: steps %5d attempts %s  J %.12f  (%.1fs)\n", tol, share,
              length(r$ode_times) - 1, paste(a, collapse = "/"), sum(r$offspring_production),
              proc.time()[[3]] - t0))
}
