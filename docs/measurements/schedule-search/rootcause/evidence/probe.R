# probe.R: a stand run forward (adjmap runner's settings, LIB/TIMES/... from the environment),
# then invader walks with the resident's own traits on its stored field at chosen birth
# dates: the per-recruit fate at any b with no feedback. PROBES = rds of birth-date vectors
# (a named list); OUT saves the stand's nodes and each walk's nodes and cost.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap"
Sys.setenv(PLANT_LIB = Sys.getenv("LIB", file.path(A, "libS")))
source("/home/user/plant-dev/harness/long_drought.R")
regime <- Sys.getenv("REGIME", SCEN); seed <- as.integer(Sys.getenv("SEED", RAIN_SPECS[[regime]]$seed))
tol <- as.numeric(Sys.getenv("TOL", "1e-4")); atol <- as.numeric(Sys.getenv("ATOL", "1e-4"))
scen <- sprintf("%s, seed %d", regime, seed); RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
knots <- active_knots(scen); times <- readRDS(Sys.getenv("TIMES"))
p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- LIFETIME; p <- add_strategies(p, trait_matrix(LMA0, "lma"))
moved <- function(q, spec) { s <- q$strategies[[1]]; for (kv in strsplit(strsplit(spec, ",")[[1]], "=")) s$pars[[kv[1]]] <- s$pars[[kv[1]]] * (1 + as.numeric(kv[2])); q$strategies[[1]] <- s; q }
if (nzchar(Sys.getenv("TRAIT_REL"))) p <- moved(p, Sys.getenv("TRAIT_REL"))
p$node_schedule_times <- list(times)
ct <- control(); ct$ode_tol_rel <- tol; ct$ode_tol_abs <- atol * tol; ct$node_density_in_birth_date <- TRUE
env_num <- function(v) as.numeric(Sys.getenv(v))
if (nzchar(Sys.getenv("WEIGHT_SOIL"))) ct$ode_tol_factor_soil <- env_num("WEIGHT_SOIL")
if (nzchar(Sys.getenv("WEIGHT"))) { w <- readRDS(Sys.getenv("WEIGHT")); ct$ode_tol_factor_times <- w$t; ct$ode_tol_factor_values <- w$weight }
if (nzchar(Sys.getenv("WEIGHT_MAX"))) ct$ode_tol_factor_max <- env_num("WEIGHT_MAX")
if (nzchar(Sys.getenv("HMAX"))) ct$ode_step_size_max <- env_num("HMAX") / 365
if (Sys.getenv("SPLIT") == "1") ct$ode_split_sign_changes <- TRUE
if (nzchar(Sys.getenv("SHARE"))) ct$ode_soil_substep_max_uptake <- env_num("SHARE")
ev <- if (Sys.getenv("KNOTS", "1") == "0") events(events_default(p)) else events(events_default(p), pulse_rows(sort(unique(knots))))
cpu <- function() sum(proc.time()[c("user.self", "sys.self")])
nodes_of <- function(scm) { sp <- scm$patch$species[[1]]; list(birth = sp$node_times, nrr = sp$net_reproduction_ratio_by_node, establishment = sp$establishment_weights) }
types <- plant:::extract_RcppR6_template_types(p, "Parameters")
scm <- do.call(plant:::SCM, types)(p, mkenv(scen), ev, ct)
c0 <- cpu(); scm$run(); out <- list(stand = list(J = sum(scm$offspring_production), nodes = nodes_of(scm), cpu = cpu() - c0, steps = length(scm$ode_times)))
cat(sprintf("stand: J %.12g, %d steps, %.1f s\n", out$stand$J, out$stand$steps, out$stand$cpu))
PR <- readRDS(Sys.getenv("PROBES")); out$walks <- list()
for (nm in names(PR)) { q <- p; q$node_schedule_times <- list(sort(PR[[nm]])); c0 <- cpu()
  res <- tryCatch({ scm$run_mutant(q); list(nodes = nodes_of(scm), J = sum(scm$offspring_production)) }, error = function(e) list(error = conditionMessage(e)))
  res$cpu <- cpu() - c0; out$walks[[nm]] <- res
  cat(sprintf("walk %s: %d probes, %.1f s%s\n", nm, length(PR[[nm]]), res$cpu, if (!is.null(res$error)) paste(" ERROR", res$error) else "")) }
saveRDS(out, Sys.getenv("OUT"))
