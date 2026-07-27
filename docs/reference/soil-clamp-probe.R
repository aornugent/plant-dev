# Does a real TF24 trajectory sit on the soil clamps?
# The severance to worry about is the drying guard at theta <= theta_r, because on the
# clamped side d(rate)/d(uptake) is zero -- the plant->soil channel is cut, not kinked.
#   NOT_CRAN=true Rscript docs/reference/soil-clamp-probe.R
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/soil-clamp-probe.cpp")

r <- soil_clamp_probe(20, 20)
cat(sprintf("theta_r = %g   theta_sat = %g   a_infil = %g   b_infil = %g   samples = %d\n",
            r$theta_r, r$theta_sat, r$a_infil, r$b_infil, r$samples))
cat("\nAt the default rainfall = 1:\n")
print(data.frame(layer = r$layer,
                 theta_min = signif(r$theta_min, 4),
                 theta_max = signif(r$theta_max, 4),
                 mult_of_theta_r = signif(r$theta_min / r$theta_r, 3),
                 at_guard = r$n_at_guard,
                 near_guard = r$n_near_guard,
                 negative = r$n_negative))
cat(sprintf("\nrunoff floor: min runoff_factor = %.4g, samples on the floor = %d\n",
            r$runoff_factor_min, r$n_runoff_floor))
cat(sprintf("saturation:   max theta over all layers = %.4g vs theta_sat = %.4g\n",
            max(r$theta_max), r$theta_sat))

# How much drier before the severance fires? A margin, not a yes/no: the answer sets
# whether a drought study can trust a TF24 gradient.
cat("\nRainfall sweep -- where does the drying guard start firing?\n")
sweep <- do.call(rbind, lapply(c(1, 0.5, 0.2, 0.1, 0.05, 0.02, 0.01, 0), function(w) {
  q <- soil_clamp_probe(20, 20, w)
  data.frame(rainfall = w,
             min_theta = signif(min(q$theta_min), 4),
             mult_of_theta_r = signif(min(q$theta_min) / q$theta_r, 3),
             layer_steps_at_guard = sum(q$n_at_guard),
             layer_steps_near = sum(q$n_near_guard),
             runoff_floor = q$n_runoff_floor)
}))
print(sweep, row.names = FALSE)
