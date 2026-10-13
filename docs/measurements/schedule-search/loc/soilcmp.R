# Each soil layer's driest state at 1e-4 against 3e-5 (long drought, a04's committed schedule),
# in moisture and in MPa via plant's retention curve.
Sys.setenv(PLANT_LIB = file.path("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap", "lib")); suppressMessages(source("/home/user/plant-dev/harness/long_drought.R"))
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
scen <- sprintf("%s, seed %d", "long-drought", RAIN_SPECS[["long-drought"]]$seed); RAIN_SPECS[[scen]] <- RAIN_SPECS[["long-drought"]]; e <- mkenv(scen)
for (t in c("1e-4", "3e-5")) { x <- readRDS(file.path(A, sprintf("rc_ld_a04_%s.rds", t))); th <- x$soil$theta
  psi <- sapply(1:5, function(l) vapply(th[, l], function(v) e$psi_from_soil_moist(v), 0))
  i <- which.max(apply(psi, 1, max))
  cat(sprintf("tol %s: %d recorded states; min theta by layer %s; max psi by layer (MPa) %s; driest at t = %.3f; states with any layer past 6.89 MPa: %d; clamps %s\n",
    t, nrow(th), paste(sprintf("%.4f", apply(th, 2, min)), collapse = " "), paste(sprintf("%.2f", apply(psi, 2, max)), collapse = " "),
    x$soil$time[i], sum(apply(psi, 1, max) > 6.89), paste(names(x$forward_clamps), x$forward_clamps, collapse = ", "))) }
