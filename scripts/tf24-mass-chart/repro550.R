# The plant#550 reprex, run under whatever size-density transport the build
# provides. `geometric` selects the transport-log-mass chart where the build
# supports it (plant branch claude/tf24-mass-chart-probe); it is inert
# otherwise. PLANT_MASS_TRACE=1 prints the state of the measure per derivs
# evaluation on the instrumented builds.
#
# Usage: Rscript repro550.R <geometric TRUE|FALSE> [max_patch_lifetime] [plant path]
args <- commandArgs(trailingOnly = TRUE)
geometric <- as.logical(args[1])
mpl <- if (length(args) > 1) as.numeric(args[2]) else 30
plant_path <- if (length(args) > 2) args[3] else "plant"

Sys.setenv(TESTTHAT_PARALLEL = "false")
suppressMessages(pkgload::load_all(plant_path, quiet = TRUE))

p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- mpl
p1 <- add_strategies(p0, trait_matrix(0.07, "lma"))

# Patch::set_ode_state overwrites each strategy's control with the patch
# control, so the run-level ctrl is what the nodes see.
ctrl <- Control()
if ("node_geometric_compression" %in% names(ctrl)) {
  ctrl$node_geometric_compression <- geometric
}

env <- Environment("TF24")
env$set_soil_number_of_depths(5)
env$set_soil_water_state(rep(0.2, 5))
x <- seq(0, mpl, length.out = mpl * 6)
y <- 0.4 * sin(2 * pi * x) + 0.5   # rainfall sweeps [0.1, 0.9]
env$extrinsic_drivers_set_variable("rainfall", x = x, y = y)

cat("=== geometric =", geometric, " mpl =", mpl, "===\n")
t0 <- Sys.time()
res <- tryCatch(run_scm(p1, env, ctrl), error = function(e) e)
el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
if (inherits(res, "error")) {
  cat("ABORT after", round(el, 1), "s\n")
  cat(conditionMessage(res), "\n")
} else {
  cat("COMPLETED after", round(el, 1), "s; offspring_production =",
      format(res$offspring_production, digits = 8), "\n")
}
