# The invader's field part from one coarse grid: the resident run with every
# panel's probe defect added to its field (light and soil, coefficient 1), the
# invader at lma e^{-U} and e^{+U} replaying that field, against the same
# invader on the unperturbed field. The difference in the invader's lma
# elasticity is the probe's prediction of the elasticity's field part.
#
#   Rscript invader_field.R TIMES SWEEP.rds OUT [ORDER] [U] [BASE_INV.rds]
#
# BASE_INV is harness/invader_nodes.R's run on the same schedule (the
# unperturbed invader), which the probe build reproduces bit for bit.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
args <- commandArgs(TRUE)
times <- readRDS(args[1]); sw <- readRDS(args[2]); out_file <- args[3]
order <- if (length(args) >= 4) as.integer(args[4]) else 1L
u <- if (length(args) >= 5) as.numeric(args[5]) else 1e-6
base_file <- if (length(args) >= 6) args[6] else ""
Sys.setenv(PLANT_LIB = file.path(A, "lib2"))
source(file.path(A, "harness", "long_drought.R"))
source(file.path(A, "probe_setup.R"))
scen <- "long-drought, seed 31"
RAIN_SPECS[[scen]] <- RAIN_SPECS[["long-drought"]]
tol <- 3e-5
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
with_lma <- function(v) { q <- p; q$strategies[[1]]$pars$lma <- q$strategies[[1]]$pars$lma * exp(v); q }
ct <- control(); ct$ode_tol_rel <- tol; ct$ode_tol_abs <- 1e-4 * tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
nodes <- function(scm) {
  sp <- scm$patch$species[[1]]
  list(birth = sp$node_times, establishment = sp$establishment_weights,
       nrr = sp$net_reproduction_ratio_by_node, J = sum(scm$offspring_production))
}
nb <- length(sw$bands) + 1; nc <- length(sw$at) * nb
one <- function(light, soil) {
  types <- plant:::extract_RcppR6_template_types(p, "Parameters")
  scm <- do.call(plant:::SCM, types)(p, mkenv(scen), ev, ct)
  plant:::field_probe_set_tf24(scm, sw$at, sw$weight, sw$bands, order, TRUE, FALSE,
                               rep(light, nc), rep(soil, nc))
  scm$record_trajectory <- TRUE
  t0 <- proc.time()[["elapsed"]]
  scm$run()
  r <- list(stand = nodes(scm))
  r$invader <- lapply(c(minus = -u, plus = u), function(v) { scm$run_mutant(with_lma(v)); nodes(scm) })
  r$secs <- proc.time()[["elapsed"]] - t0
  J <- vapply(r$invader, `[[`, 0, "J")
  r$elasticity <- (J[["plus"]] - J[["minus"]]) / (2 * u * r$stand$J)
  cat(sprintf("light %g soil %g: stand J %.10f; invader lma elasticity %.6f; %.0f s\n",
              light, soil, r$stand$J, r$elasticity, r$secs))
  r
}
out <- list(times = times, u = u, order = order, setting = list(regime = "long-drought", tol = tol, lifetime = LIFETIME))
if (nzchar(base_file)) {
  b <- readRDS(base_file)
  stopifnot(isTRUE(all.equal(b$node_times, times)), b$u == u)
  J <- vapply(b$invader, `[[`, 0, "J")
  out$base <- list(stand = b$stand, invader = b$invader,
                   elasticity = (J[["plus"]] - J[["minus"]]) / (2 * u * b$stand$J), from = base_file)
  cat(sprintf("base (from %s): invader lma elasticity %.6f\n", basename(base_file), out$base$elasticity))
} else {
  out$base <- one(0, 0)
}
saveRDS(out, out_file)
out$both <- one(1, 1); saveRDS(out, out_file)
cat(sprintf("predicted field part of the invader's lma elasticity: %+.4f\n", out$both$elasticity - out$base$elasticity))
out$light <- one(1, 0); saveRDS(out, out_file)
cat(sprintf("by channel: light %+.4f, soil (both less light) %+.4f\n", out$light$elasticity - out$base$elasticity,
            out$both$elasticity - out$light$elasticity))
