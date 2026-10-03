# One record's stand under the bounded Cash-Karp setting (run_record.R's), then
# the stand's own invader and eight more walked on its recording, no sweeps.
# Keeps per node what an exact emulation of a thinned schedule needs: birth,
# establishment weight, the interval's establishment integral and moment,
# fecundity, patch density at birth, S_D and the birth rate.
#
#   PLANT_LIB=... REGIME=long-drought OUT=walks_ld.rds Rscript walks.R
local({
  source("harness/long_drought.R")
})
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
regime <- Sys.getenv("REGIME")
out_file <- Sys.getenv("OUT")
seed <- RAIN_SPECS[[regime]]$seed
scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
knots <- active_knots(scen)
times <- readRDS(file.path(D, "window/t/t_u108.rds"))
tol <- 3e-5

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- 1e-4 * tol
ct$node_density_in_birth_date <- TRUE
ct$ode_weight_soil <- 10
w <- readRDS(file.path(D, sprintf("window/rule_A/weight_%s.rds", regime)))
ct$ode_weight_times <- w$t
ct$ode_weight_factors <- w$weight
ct$ode_weight_max <- 100
ct$ode_step_size_max <- 15 / 365
ev <- events(events_default(p), pulse_rows(sort(unique(knots))))

clock <- function() proc.time()[["elapsed"]]
per_node <- function(scm, q) {
  sp <- scm$patch$species[[1]]
  state <- matrix(sp$ode_state, ncol = sp$size, dimnames = list(sp$new_node$ode_names))
  b <- sp$node_times
  list(birth = b, w = sp$establishment_weights, nrr = sp$net_reproduction_ratio_by_node,
       pd = sp$patch_densities, E = state["interval_establishment", ],
       M = state["interval_establishment_moment", ], height = state["height", ],
       mortality = state["mortality", ], S_D = q$strategies[[1]]$pars[["S_D"]],
       br = vapply(b, function(t) sp$extrinsic_drivers$evaluate("birth_rate", t), 0))
}
out <- list(regime = regime, node_times = times, walks = list())
t0 <- clock()
scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
out$stand <- list(J = sum(scm$offspring_production), times = scm$ode_times,
                  nodes = per_node(scm, p), secs = clock() - t0)
saveRDS(out, out_file)
inv <- c("stand=1", "lma=2", "lma=0.5", "hmat=2", "hmat=0.5", "lma=1.4", "lma=0.7", "hmat=1.4", "hmat=0.7")
for (k in inv) {
  kv <- strsplit(k, "=")[[1]]
  q <- if (kv[1] == "stand") p else stand_at(times, kv[1], as.numeric(kv[2]))
  t0 <- clock()
  r <- tryCatch({ scm$run_mutant(q); TRUE }, error = function(e) conditionMessage(e))
  out$walks[[k]] <- if (isTRUE(r)) list(J = sum(scm$offspring_production), nodes = per_node(scm, q),
                                        secs = clock() - t0) else list(error = r)
  saveRDS(out, out_file)
}
out$finished <- format(Sys.time(), tz = "UTC", usetz = TRUE)
saveRDS(out, out_file)
cat(sprintf("%s: J %.10g, %d steps, %s\n", regime, out$stand$J, length(out$stand$times),
            paste(sprintf("%s %.6g", names(out$walks), vapply(out$walks, function(x) if (is.null(x$J)) NA else x$J, 0)), collapse = ", ")))
