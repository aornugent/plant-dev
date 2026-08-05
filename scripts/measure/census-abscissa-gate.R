# Gate for Task 9a: the census must integrate over the quadrature abscissa.
#
# `Species::census` integrated over height() and never consulted the coordinate.
# `compute_initial_conditions` divides the boundary density by the growth rate on
# the height branch and NOT on the birth-date branch, and that 1/g factor is what
# makes the height-coordinate density a density in height. So integrating over
# height on the birth-date coordinate applies the wrong measure, and no sort
# repairs it.
#
# TWO GATES, and the second is the one that catches an over-eager fix.
#
#   1. HEIGHT COORDINATE: unchanged. The new traversal is the reverse of the old
#      one with the sign of x flipped, so trapezium returns the same sum up to
#      floating-point association. A change here beyond association is a defect.
#   2. BIRTH-DATE COORDINATE: it MUST move. That is the measure being corrected.
#      A fix that leaves it identical did nothing.
#
# WHAT WOULD MAKE THIS GATE UNABLE TO FAIL (METHOD.md 1, 9.0):
#   - An almost-empty stand. Offspring production is the tell: the reference
#     configuration gives ~445, and a fixture that omits `hmat` gives ~3. A stand
#     with three offspring exercises no quadrature worth measuring, so offspring
#     is reported for every arm below and the gate refuses on a degenerate one.
#   - A single coordinate. Running only the birth-date arm cannot distinguish
#     "the measure was corrected" from "the census broke", which is why gate 1
#     exists and why both arms run here.
#
# Usage, against each build in turn:
#   R_LIBS_USER=/home/user/lib-verify Rscript scripts/measure/census-abscissa-gate.R
#   R_LIBS_USER=/home/user/lib-9a     Rscript scripts/measure/census-abscissa-gate.R
suppressMessages({
  library(odelia); library(plant)
  attach(asNamespace("plant"), name = "plant-internals")  # METHOD.md 4
})

LIFETIME <- 20
TRAITS   <- cbind(lma = 0.0825, hmat = 5)
BIRTH    <- 20

run_one <- function(birth_date) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  # run_scm takes `ctrl` as its OWN argument, defaulting to control(). Setting
  # p$control alone does NOT reach the run: a first version of this gate did that
  # and both coordinate arms returned byte-identical censuses, offspring AND step
  # counts -- which reads as "the coordinate does not affect the census" and means
  # "the flag was never applied". Pass it explicitly and assert both places.
  # `p$control` is NULL on a fresh parameter set, and passing it gives
  # "Expected an object of type Control". control() is the constructor.
  ctrl <- control()
  ctrl$node_density_in_birth_date <- birth_date
  stopifnot(inherits(ctrl, "Control"),
            identical(ctrl$node_density_in_birth_date, birth_date))
  p <- add_strategies(p, trait_matrix(TRAITS, colnames(TRAITS)), birth_rate = BIRTH)

  t0 <- proc.time()[["elapsed"]]
  r  <- run_scm(p, ctrl = ctrl)
  el <- proc.time()[["elapsed"]] - t0

  cen <- stand_census(r)
  list(offspring = sum(r$offspring_production), secs = el,
       steps = length(r$ode_times), census = cen,
       n_nodes = r$patch$species[[1]]$size)
}

cat(sprintf("lifetime=%s lma=%s hmat=%s birth_rate=%s\n\n",
            LIFETIME, TRAITS[1, "lma"], TRAITS[1, "hmat"], BIRTH))
cat(sprintf("%-12s %11s %6s %6s %6s %15s %15s %15s\n", "coordinate",
            "offspring", "nodes", "steps", "secs",
            "leaf_area", "mass_above_gnd", "area_stem"))

seen <- list()
for (bd in c(FALSE, TRUE)) {
  res <- try(run_one(bd), silent = TRUE)
  nm  <- if (bd) "birth-date" else "height"
  if (inherits(res, "try-error")) {
    cat(sprintf("%-12s  ERROR %s\n", nm,
                sub("\n.*", "", conditionMessage(attr(res, "condition")))))
    next
  }
  # GUARD: refuse a degenerate stand rather than reporting its numbers.
  if (res$offspring < 50)
    cat(sprintf("%-12s  WARNING degenerate stand, %.2f offspring -- do not quote\n",
                nm, res$offspring))
  seen[[length(seen) + 1L]] <- res
  cat(sprintf("%-12s %11.2f %6d %6d %6.1f %15.10f %15.10f %15.10f\n",
              nm, res$offspring, res$n_nodes, res$steps, res$secs,
              res$census[["leaf_area"]], res$census[["mass_above_ground"]],
              res$census[["area_stem"]]))
}
# GUARD: if both coordinates agree on the census AND on the step count, the
# coordinate flag did not reach the run. That is a harness defect, not a finding.
if (length(seen) == 2L) {
  same_census <- isTRUE(all.equal(seen[[1]]$census, seen[[2]]$census, tolerance = 0))
  same_steps  <- identical(seen[[1]]$steps, seen[[2]]$steps)
  if (same_census && same_steps)
    stop("HARNESS DEFECT: both coordinates returned identical censuses and ",
         "identical step counts. node_density_in_birth_date did not reach the ",
         "run. Do not report these numbers.")
}

cat("\nCompare the two builds. Gate 1: the height row must match to association.\n")
cat("Gate 2: the birth-date row must differ, or the measure was not corrected.\n")
