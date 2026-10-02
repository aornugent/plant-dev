# Long drought on a schedule, with each node's height, mortality integral and
# survival-weighted offspring at sample times 0.05 apart, for the nodes born
# before the first gap.
#
#   PLANT_LIB=... TIMES=t.rds [REGIME=long-drought] OUT=x.rds Rscript harness/layer_heights.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
regime <- Sys.getenv("REGIME", SCEN)
times <- readRDS(Sys.getenv("TIMES"))
scen <- sprintf("%s, seed %d", regime, RAIN_SPECS[[regime]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[regime]]
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- 3e-5
ct$ode_tol_abs <- 3e-9
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)

sp <- scm$patch$species[[1]]
per <- length(sp$ode_state) / sp$size
nm <- sp$new_node$ode_names
rows <- scm$store_trajectory()
t <- vapply(rows, `[[`, 0, "time")
len <- lengths(lapply(rows, `[[`, "state"))
# The nodes each row holds: its state less what the final row holds beside them.
held <- (len - (tail(len, 1) - per * sp$size)) / per
keep <- which(times < 3.6)
grid <- seq(0.05, 40, by = 0.05)
at <- vapply(grid, function(g) max(which(t <= g)), 0L)
pick <- function(name) {
  k <- which(nm == name)
  sapply(keep, function(j) vapply(at, function(i)
    if (held[i] >= j) rows[[i]]$state[per * (j - 1) + k] else NA_real_, 0))
}
out <- list(times = times[keep], grid = grid, height = pick("height"),
            mortality = pick("mortality"), offspring = pick("offspring_produced_survival_weighted"),
            nrr = sp$net_reproduction_ratio_by_node[keep], w = sp$establishment_weights[keep],
            eta = p$strategies[[1]]$pars$eta, J = sum(scm$offspring_production))
saveRDS(out, Sys.getenv("OUT"))
cat(sprintf("J %.8g; %d nodes kept over %d sample times\n", out$J, length(keep), length(grid)))
