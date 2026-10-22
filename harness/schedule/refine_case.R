# Refine one case's schedule at round 5's run setting and save the fit:
#   PLANT_LIB=... Rscript harness/schedule/refine_case.R CASE OUT [SCALE]
# from the plant-dev root, with plant built from the open TF24 stack (PLANT-117 or later).
source(file.path(Sys.getenv("PLANT_DEV", "."), "harness/long_drought.R"))
source(file.path(Sys.getenv("PLANT_DEV", "."), "harness/schedule/refine.R"))
# The tolerance weights over patch age (control_window's rule A), one per rainfall record.
WEIGHTS <- file.path(Sys.getenv("PLANT_DEV", "."), "harness/schedule/data/weights")
CASES <- list(
  dry = list(regime = "dry", trait = c(), weight = "dry"),
  `long-wet` = list(regime = "long-wet", trait = c(), weight = "long-wet"),
  `episodic-lma` = list(regime = "episodic", trait = c(lma = 1.25), weight = "episodic"),
  `dry-flat` = list(regime = "dry-flat", trait = c(), weight = "dry"),
  `epi-adG208` = list(regime = "episodic", trait = c(a_dG2 = 0.8), weight = "episodic"))
a <- commandArgs(TRUE); case <- CASES[[a[1]]]; scale <- if (length(a) > 2) as.numeric(a[3]) else 1

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
for (n in names(case$trait)) p$strategies[[1]]$pars[[n]] <- p$strategies[[1]]$pars[[n]] * case$trait[[n]]
ctrl <- control()
ctrl$ode_tol_rel <- 1e-4
ctrl$ode_tol_abs <- 1e-8
ctrl$node_density_in_birth_date <- TRUE
ctrl$ode_tol_factor_soil <- 10
w <- readRDS(file.path(WEIGHTS, sprintf("weight_%s.rds", case$weight)))
ctrl$ode_tol_factor_times <- w$t
ctrl$ode_tol_factor_values <- w$weight
ctrl$ode_tol_factor_max <- 100
ctrl$ode_step_size_max <- 15 / 365
ctrl$ode_soil_substep_max_uptake <- 0.1

fit <- refine_schedule(p, mkenv(case$regime), ctrl, scale)
saveRDS(fit, a[2])
if (fit$status == "failed") cat(a[1], ": failed: ", fit$error, "\n", sep = "") else
  cat(sprintf("%s: %s after %d passes, worst bound %.2f (%s), %d nodes\n", a[1], fit$status, length(fit$history),
              max(fit$bound), names(fit$bound)[which.max(fit$bound)], length(nodes_of(fit$schedule, fit$level))))
