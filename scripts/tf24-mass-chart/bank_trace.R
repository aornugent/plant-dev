# What actually diverges on a crashing stress-bank trace? Runs one trace at the
# bank's settings and, optionally, at a tighter integrator tolerance, so the
# "the divergence is in the equations, not the stepper" claim can be checked
# rather than inherited. With PLANT_MASS_TRACE=1 the instrumented build prints
# the extremes of the size-density measure and every environment state per
# derivs evaluation.
#
# Usage: Rscript bank_trace.R <trace name> <tol|default> [plant path]
args <- commandArgs(trailingOnly = TRUE)
nm <- args[1]
tol <- args[2]
plant_path <- if (length(args) > 2) args[3] else "plant"

options(pkg.build_extra_flags = FALSE)
suppressMessages(pkgload::load_all(plant_path, export_all = TRUE, quiet = TRUE))

b <- readRDS(file.path("scripts/tf24-benchmarks/data", paste0(nm, ".rds")))
tt <- (0:(length(b$rain) - 1)) / 365

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- max(tt)
p1 <- add_strategies(p, trait_matrix(0.0825, "lma"), hyperpar = TF24_hyperpar,
                     birth_rate = list(20))
mke <- function() {
  e <- Environment("TF24")
  e$extrinsic_drivers_set_variable("rainfall", tt, b$rain)
  e
}
ctrl <- control()
ctrl$GSS_tol_abs <- 1e-12
ctrl$ci_abs_tol <- 1e-12
if (tol != "default") {
  ctrl$ode_tol_rel <- as.numeric(tol)
  ctrl$ode_tol_abs <- as.numeric(tol)
}

cat("=== ", nm, " horizon", round(max(tt), 1), "yr  tol =", tol, "===\n")
t0 <- Sys.time()
res <- tryCatch(run_scm(p1, mke(), ctrl), error = function(e) e)
el <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
if (inherits(res, "error")) {
  cat("ABORT after", el, "s:", substr(conditionMessage(res), 1, 220), "\n")
} else {
  cat("COMPLETED after", el, "s; offspring =",
      format(sum(res$offspring_production), digits = 8), "\n")
}
