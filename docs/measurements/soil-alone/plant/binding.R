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
ctrl <- function(share, tol = 1e-4) {
  x <- control_tf24(tol, Control(node_density_in_birth_date = TRUE, ode_split_sign_changes = TRUE))
  x$ode_soil_alone_share <- share
  x
}
n_env <- Environment("TF24")$ode_size
n_soil <- Environment("TF24")$get_soil_number_of_depths()
binding <- function(scm) {
  rows <- Filter(function(r) !r$introduction && !is.na(r$error_index), scm$store_trajectory())
  kind <- vapply(rows, function(r) {
    at <- r$error_index - (length(r$state) - n_env)
    if (at > n_soil) "accumulator" else if (at > 0) paste0("soil", at) else "node"
  }, "")
  h <- vapply(rows, function(r) r$step_size, 0)
  t <- vapply(rows, function(r) r$time, 0)
  list(table(kind), h = h, t = t, kind = kind)
}
for (tol in c(1e-4, 1e-7)) for (share in c(0, 0.1)) {
  r <- run_scm(p, env(), ctrl(share, tol), record_trajectory = TRUE)
  b <- binding(r)
  cat(sprintf("tol %.0e share %.1f: steps %d J %.6e\n", tol, share, length(r$ode_times) - 1, sum(r$offspring_production)))
  print(b[[1]])
  cat("  median h (days):", round(365 * median(b$h), 3), " max h:", round(365 * max(b$h), 2), "\n")
  q <- quantile(b$t, c(.25, .5, .75)); 
  for (yr in 0:2) { s <- b$t >= yr & b$t < yr + 1; cat(sprintf("  year %d: %d steps; ", yr, sum(s))) }; cat("\n")
}
