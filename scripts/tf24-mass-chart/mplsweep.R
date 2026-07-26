# Which failure mode does the #550 reprex hit across its stated lifetime range
# (20-70 yr)? Production path (chart off) unless asked otherwise.
Sys.setenv(TESTTHAT_PARALLEL = "false")
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet = TRUE))

run1 <- function(mpl, geometric = FALSE) {
  p0 <- scm_base_parameters("TF24", "TF24_Env")
  p0$max_patch_lifetime <- mpl
  p1 <- add_strategies(p0, trait_matrix(0.07, "lma"))
  ctrl <- Control()
  ctrl$node_geometric_compression <- geometric
  env <- Environment("TF24")
  env$set_soil_number_of_depths(5)
  env$set_soil_water_state(rep(0.2, 5))
  x <- seq(0, mpl, length.out = mpl * 6)
  env$extrinsic_drivers_set_variable("rainfall", x = x, y = 0.4 * sin(2 * pi * x) + 0.5)
  res <- tryCatch(run_scm(p1, env, ctrl), error = function(e) e)
  if (inherits(res, "error")) {
    m <- conditionMessage(res)
    mode <- if (grepl("environment state", m)) "soil (mode 2)" else
            if (grepl("cohort density", m)) "density (mode 1)" else "other"
    sprintf("mpl=%-3g geom=%-5s ABORT %-16s t=%s", mpl, geometric, mode,
            sub(".*at time=([0-9.]+).*", "\\1", m))
  } else {
    sprintf("mpl=%-3g geom=%-5s COMPLETED offspring=%.6g", mpl, geometric,
            res$offspring_production)
  }
}

for (m in c(20, 25, 40, 50, 70)) for (g in c(FALSE, TRUE)) cat(run1(m, g), "\n")
