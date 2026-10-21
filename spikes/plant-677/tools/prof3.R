suppressMessages(library(plant))
m <- Sys.getenv("MODEL")
if (m == "FF16") {
  p <- scm_base_parameters("FF16"); p$max_patch_lifetime <- 8
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = list(1)); env <- NULL
} else {
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- 2
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), hyperpar = TF24_hyperpar, birth_rate = 1)
  env <- Environment("TF24"); env$extrinsic_drivers_set_constant("rainfall", 1)
}
ctrl <- Control(node_density_in_birth_date = TRUE)
scm <- run_scm(p, env, ctrl, record_trajectory = TRUE)
g <- if (Sys.getenv("METRICS") == "all") stand_gradient(scm) else stand_gradient(scm, metrics = names(stand_census(scm))[1])
cat("STEPS", length(scm$ode_times), "COHORTS", scm$patch$species[[1]]$size, "\n")
saveRDS(g, file.path(Sys.getenv("S"), sprintf("g_%s_%s.rds", m, Sys.getenv("LIB"))))
