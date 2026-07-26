# Can the fitted spline carry the query-height derivative accurately enough that the
# exact field is unnecessary? The spline is the smaller change from the forward model,
# so it wins if its tangent is good enough.
#   NOT_CRAN=true Rscript docs/reference/spline-tangent-probe.R
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/spline-tangent-probe.cpp")
cat(sprintf("%7s %6s %6s | %10s %10s | %10s %10s | %10s %10s\n", "tol",
            "nd_E", "nd_A", "maxsl_E", "maxsl_A", "meansl_E", "meansl_A",
            "valerr_E", "valerr_A"))
for (tol in c(1e-3, 1e-4, 1e-5, 1e-6, 1e-8)) {
  r <- spline_tangent_probe(tol = tol)
  cat(sprintf("%7.0e %6d %6d | %10.2e %10.2e | %10.2e %10.2e | %10.2e %10.2e\n", tol,
              r$nodes_light, r$nodes_depth,
              r$max_slope_reld_light, r$max_slope_reld_depth,
              r$mean_slope_reld_light, r$mean_slope_reld_depth,
              r$max_value_err_light, r$max_value_err_depth))
}
cat("\nslope columns: relative error in d(light)/dz against the field's exact value.\n")
cat("E = spline fitted to light; A = spline fitted to optical depth, light recovered as exp(-A).\n")
