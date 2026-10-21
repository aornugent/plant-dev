suppressMessages(library(plant))
out <- list()
for (L in c(8, 30)) {
  p <- scm_base_parameters("FF16"); p$max_patch_lifetime <- L
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = list(1))
  scm <- run_scm(p, NULL, Control(node_density_in_birth_date = TRUE), record_trajectory = TRUE)
  g <- stand_gradient(scm)
  out[[as.character(L)]] <- list(steps = length(scm$ode_times), value = g$value, gradient = g$gradient)
}
saveRDS(out, Sys.getenv("OUT"))
