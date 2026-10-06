.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_rr", .libPaths())); suppressMessages(library(plant))
here <- "/home/user/plant-dev/harness"; source(file.path(here, "long_drought.R"))
cat("SCEN", SCEN, "LIFETIME", LIFETIME, "LMA0", LMA0, "\n")
p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
times <- uniform_times(108); p$node_schedule_times <- list(times)
ct <- control(); ct$ode_tol_rel <- 1e-4; ct$ode_tol_abs <- 1e-8; ct$node_density_in_birth_date <- TRUE
env <- mkenv(SCEN)
patch <- plant:::Patch("TF24", "TF24_Env")(p, env, ct)
patch$introduce_new_node(1L, times[1]); y <- patch$ode_state
d <- patch$derivs(y, 0)
cat("state", length(y), "aux", length(patch$ode_aux), "\n")
s <- p$strategies[[1]]
print(head(patch$species[[1]]$new_node$ode_names, 12))
nm <- tryCatch(patch$species[[1]]$new_node$individual$aux_names, error = function(e) NULL); print(nm)
print(head(patch$ode_aux, 13))
