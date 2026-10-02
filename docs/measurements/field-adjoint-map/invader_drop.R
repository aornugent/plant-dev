# The invader's field part by the drop probe: the resident on the finer
# schedule, its field with and without the defect of dropping the nodes the
# coarser schedule lacks, and the invader on the coarser schedule at lma e^{+-U}
# replaying each. Invaders do not shade or drink, so an invader node's fate is
# set by its birth date and the field alone: the difference in the invader's
# lma elasticity between the two fields is the field part of its move from the
# coarser to the finer resident grid.
#
#   Rscript invader_drop.R FINE_TIMES COARSE_TIMES OUT [U] [LIGHT_ONLY]
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
args <- commandArgs(TRUE)
fine <- readRDS(args[1]); coarse <- readRDS(args[2]); out_file <- args[3]
u <- if (length(args) >= 4) as.numeric(args[4]) else 1e-6
light_only <- length(args) >= 5 && args[5] == "1"
Sys.setenv(PLANT_LIB = file.path(A, "lib2"))
source(file.path(A, "harness", "long_drought.R"))
scen <- "long-drought, seed 31"
RAIN_SPECS[[scen]] <- RAIN_SPECS[["long-drought"]]
tol <- 3e-5
base_p <- function(times) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"))
  p$node_schedule_times <- list(times)
  p
}
p <- base_p(fine)
# The invader walks the resident's recorded rows, introductions included, so it
# takes the resident's schedule; its coarser nodes are read off it afterwards.
invader <- function(v) { q <- base_p(fine); q$strategies[[1]]$pars$lma <- q$strategies[[1]]$pars$lma * exp(v); q }
ct <- control(); ct$ode_tol_rel <- tol; ct$ode_tol_abs <- 1e-4 * tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
BANDS <- c(0.5, 1, 2, 3, 5, 10, 20); nb <- length(BANDS) + 1
at <- ifelse(round(fine, 10) %in% round(coarse, 10), NaN, fine)
nc <- length(at) * nb
nodes <- function(scm) {
  sp <- scm$patch$species[[1]]
  list(birth = sp$node_times, establishment = sp$establishment_weights,
       nrr = sp$net_reproduction_ratio_by_node, J = sum(scm$offspring_production))
}
one <- function(light, soil) {
  types <- plant:::extract_RcppR6_template_types(p, "Parameters")
  scm <- do.call(plant:::SCM, types)(p, mkenv(scen), ev, ct)
  plant:::field_probe_set_tf24(scm, at, rep(NaN, length(at)), BANDS, 1L, TRUE, TRUE,
                               rep(light, nc), rep(soil, nc))
  t0 <- proc.time()[["elapsed"]]
  scm$run()
  r <- list(stand = nodes(scm))
  r$invader <- lapply(c(minus = -u, plus = u), function(v) { scm$run_mutant(invader(v)); nodes(scm) })
  r$secs <- proc.time()[["elapsed"]] - t0
  J <- vapply(r$invader, `[[`, 0, "J")
  r$elasticity <- (J[["plus"]] - J[["minus"]]) / (2 * u * r$stand$J)
  cat(sprintf("drop light %g soil %g: stand J %.10f; invader (on %d nodes) lma elasticity %.6f; %.0f s\n",
              light, soil, r$stand$J, length(fine), r$elasticity, r$secs))
  r
}
out <- list(fine = fine, coarse = coarse, u = u)
# The invader in the finer field without the defect is invader_nodes.R's run on
# the finer schedule, which this build reproduces bit for bit.
out$dropped <- one(1, 1); saveRDS(out, out_file)
if (light_only) { out$light <- one(1, 0); saveRDS(out, out_file) }
