# plant-115: one run of a TF24 stand under one way of meeting the rain's knots.
#   PLANT_LIB=<lib> Rscript soil-run.R <scenario> <arm> <tol> <gradient: 0|1> <out.csv>
# scenario:
#   synthetic - harness/long_drought.R: the synthetic 41-year daily record, one
#               species at lma 0.32, 108 uniform introductions over 40 years;
#   seasonal  - plant's "seasonal" reference regime (ladder_reference_regimes():
#               rain 1 + sin(2 pi t) m/yr, knots every 7.6 days) on a 10-year
#               one-species stand at the fixture's traits, birth rate 1.10,
#               the default schedule (93 introductions).
# arm:
#   stops    - a zero-depth rainfall pulse at every knot, so no step spans one
#              (develop's way); uptake fraction 0;
#   free     - no stops, uptake fraction 0 (on B105 a step spanning a knot
#              substeps the soil; on B107 it reads the rain at its stages only);
#   free0.1  - no stops, uptake fraction 0.1 (B105 only).
# Birth date, ode_tol_rel = ode_tol_abs = tol.
args <- commandArgs(TRUE)
scen <- args[[1]]; arm <- args[[2]]; tol <- as.numeric(args[[3]])
grad <- args[[4]] == "1"; out <- args[[5]]
lib <- Sys.getenv("PLANT_LIB")
v2 <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/v2"
if (scen == "synthetic") {
  source("/home/user/plant-dev/harness/long_drought.R")
} else {
  .libPaths(c(lib, .libPaths()))
  suppressMessages({library(odelia); library(plant)})
  source(file.path(v2, "src-helpers", "helper-gradient-ladder.R"))
}
source(file.path(v2, "probe", "load_probe.R")); load_rejection_probe(lib)
cpu <- function(t) sum(t[c("user.self", "sys.self")])
ctrl <- Control(node_density_in_birth_date = TRUE, ode_tol_rel = tol, ode_tol_abs = tol)
if (arm == "free0.1") ctrl$ode_soil_substep_max_uptake <- 0.1
if (scen == "synthetic") {
  p <- stand_at(uniform_times(108)); env <- mkenv(); knots <- AK
} else {
  lifetime <- 10
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- lifetime
  tr <- c(lma = 0.0825, hmat = 5.13, k_I = 0.5, a_l1 = 5.44, a_l2 = 0.306)
  p <- add_strategies(p, trait_matrix(unname(tr), names(tr)),
                      hyperpar = TF24_hyperpar, birth_rate = list(1.10))
  env <- ladder_environment(1, 1, lifetime)
  kt <- seq(0, lifetime, length.out = max(200L, as.integer(ceiling(lifetime * 48))))
  knots <- kt[kt > 0 & kt < lifetime]
}
ev <- if (arm == "stops") events(events_default(p), rainfall_pulse(time = knots, depth = rep(0, length(knots)))) else NULL
t0 <- proc.time()
scm <- run_scm(p, env, ctrl, events = ev, record_trajectory = grad)
fwd <- cpu(proc.time() - t0)
sweep <- NA; g <- NULL
if (grad) {
  t0 <- proc.time(); g <- stand_gradient(scm); sweep <- cpu(proc.time() - t0)
}
tt <- scm$ode_times
nodes <- scm$patch$species[[1]]$node_times
ends <- if (is.null(scm$ode_soil_substep_ends)) list() else scm$ode_soil_substep_ends
row <- data.frame(build = basename(lib), scenario = scen, arm = arm, tol = tol,
  J = sum(scm$offspring_production), lnJ = log(sum(scm$offspring_production)),
  accepted = length(tt) - 1, rejected = scm_rejections_tf24(scm$.ptr),
  rows = sum(vapply(tt[-length(tt)], function(t) sum(nodes <= t), 0)),
  steps_substepped = sum(lengths(ends) > 0), soil_substeps = sum(lengths(ends)),
  forward_cpu_s = fwd, sweep_cpu_s = sweep)
print(row)
write.table(row, out, sep = ",", row.names = FALSE, append = file.exists(out),
            col.names = !file.exists(out))
if (grad) saveRDS(list(row = row, value = g$value, gradient = g$gradient,
                       pars = unlist(p$strategies[[1]]$pars)),
                  sub("\\.csv$", sprintf("-%s-%s-%s-%g.rds", basename(lib), scen, arm, tol), out))
