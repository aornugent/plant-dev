# What does one unit of the step-local sweep cost in plant?
# The design's 4.2x time figure came from a toy at ~22 us/unit whose restore is trivial.
# plant's restore reinstalls the light spline and re-runs compute_environment + compute_rates
# over every cohort, per unit. This prices it.
#   NOT_CRAN=true Rscript docs/reference/unit-cost-probe.R
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/unit-cost-probe.cpp")

# Production unit counts, from v3-facts.md section 1.
units <- c(FF16 = 264, TF24 = 2598)
for (m in c("FF16", "TF24")) {
  for (life in c(10, 20)) {
    r <- unit_cost_probe(m, 20, life, 10)
    # advance is measured over the LAST segment, which holds many ODE steps (TF24's
    # end-of-run transient). The STEP unit advances one step, so normalise -- multiplying
    # the whole segment by the unit count would double-count badly.
    adv_step <- r$advance_us / r$steps_in_unit
    unit_step <- r$copy_us + r$restore_us + adv_step
    cat(sprintf(paste0("%-5s life=%-3g cohorts=%-4d steps in probed segment=%-4d | ",
                       "copy=%6.1f restore=%7.1f advance/step=%9.1f  unit(1 step)=%9.1f us",
                       " | restore is %4.1f%% of a unit -> x%d units = %.1f s\n"),
                m, life, r$cohorts, r$steps_in_unit,
                r$copy_us, r$restore_us, adv_step, unit_step,
                100 * r$restore_us / unit_step, units[[m]], unit_step * units[[m]] / 1e6))
    flush(stdout())
  }
}
