# Direct measurement of the snapshot-interpolation artefact at 64 and 128 m2.
# The oracle can only be read at introduction events.  L(t) is close to
# exponential at these ages, so log-linear interpolation between the bracketing
# events is near-exact while plain linear interpolation is biased high by
# ~(k*dt)^2/8.  Their difference IS the artefact, measured rather than bounded.
# Reported alongside: the exact value when the target age lands on an event.
suppressMessages(library(plant)); source("probes/lib.R"); setwd("/home/user/plant-dev")
TEND <- 3.5; AGES <- c(1, 1.5, 2, 2.5, 3)
SOIL <- c(wet = 0.310613, dry = 0.299220)
p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))

traj <- function(area, seed, sw, off) {
  set.seed(seed); p <- p0; p$patch_area <- area; p$max_patch_lifetime <- TEND
  e <- Environment("TF24"); e$set_soil_water_state(rep(sw, length(e$get_soil_water_state())))
  dt <- 1/area; aa <- seq(off*dt, TEND, by = dt)
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, e, Control())
  sc <- plant:::NodeSchedule(1); sc$max_time <- TEND; sc$set_times(aa, 1)
  obj$node_schedule <- sc
  tm <- c(); la <- c()
  snap <- function() { sp <- obj$patch$species[[1]]
    tm <<- c(tm, obj$patch$time); la <<- c(la, sp$compute_competition(0)/area) }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm) & la > 0
  list(t = tm[ok], L = la[ok])
}
lin <- function(d, g) approx(d$t, d$L, g, rule=2)$y
lg  <- function(d, g) exp(approx(d$t, log(d$L), g, rule=2)$y)

cat("=== interpolation artefact, midpoint placement (off = 0.5*dt) ===\n")
cat(sprintf("%-6s %-4s %-9s %s\n","area","soil","estimator",
    paste(sprintf("%11s", sprintf("L(%.1f)", AGES)), collapse=" ")))
for (A in c(64, 128)) for (sn in names(SOIL)) {
  d <- traj(A, 7770000 + 1000*A + 1, SOIL[[sn]], 0.5)
  a <- lin(d, AGES); b <- lg(d, AGES)
  cat(sprintf("%-6g %-4s %-9s %s\n", A, sn, "linear",   paste(sprintf("%11.6f", a), collapse=" ")))
  cat(sprintf("%-6g %-4s %-9s %s\n", A, sn, "loglinear",paste(sprintf("%11.6f", b), collapse=" ")))
  cat(sprintf("%-6g %-4s %-9s %s   <-- artefact\n", A, sn, "lin/log-1",
      paste(sprintf("%10.4f%%", 100*(a/b-1)), collapse=" ")))
  cat(sprintf("%-6g %-4s dlnL/dt   %s\n\n", A, sn,
      paste(sprintf("%11.2f", diff(log(b))/diff(AGES))[c(1,1:4)], collapse=" ")))
  flush.console()
}
cat("For reference: the same diagnostic at 4 m2 (Poisson gaps ~0.25 y)\n")
d <- traj(4, 7774001, SOIL[["wet"]], 0.5)
a <- lin(d, AGES); b <- lg(d, AGES)
cat(sprintf("  4      wet  linear    %s\n", paste(sprintf("%11.6f", a), collapse=" ")))
cat(sprintf("  4      wet  loglinear %s\n", paste(sprintf("%11.6f", b), collapse=" ")))
cat(sprintf("  4      wet  lin/log-1 %s\n", paste(sprintf("%10.4f%%", 100*(a/b-1)), collapse=" ")))
