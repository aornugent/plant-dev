Sys.setenv(PLANT_LIB = "/home/a/.claude/jobs/9d586e52/rlib-leaf")
Sys.setenv(LIFETIME = "40")
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/harness/long_drought.R")
CASE <- Sys.getenv("CASE", "closed")
REGIME <- if (CASE == "open") "long-drought" else "long-wet"
LMA_SHIFT <- if (CASE == "open") 0 else -1
LNB <- if (CASE == "open") 1.539 else 3.595
TIMES <- uniform_times(108)
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- 40
p$strategy_default$collect_all_auxiliary <- TRUE
p <- add_strategies(p, trait_matrix(LMA0 * exp(LMA_SHIFT), "lma"), birth_rate = exp(LNB))
p$node_schedule_times <- list(TIMES)
ctrl <- control(); ctrl$ode_tol_rel <- 1e-4; ctrl$ode_tol_abs <- 1e-8
ctrl$node_density_in_birth_date <- TRUE
res <- run_scm(p, mkenv(REGIME), ctrl, collect = TRUE)
print(names(res)); print(log(res$net_reproduction_ratios))
str(res$species, max.level = 1)
saveRDS(res, sprintf("/tmp/front/%s.rds", CASE))
