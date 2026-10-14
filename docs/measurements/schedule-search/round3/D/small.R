# Small reproduction: heavy constant rain on a wet top layer, loose soil error level.
# Every accepted step's h * |d rate1 / d theta1| (finite difference through the
# environment's own compute_rates) against RKCK's real stability limit 3.73.
lib <- Sys.getenv("LIB"); if (nzchar(lib)) .libPaths(c(lib, .libPaths()))
suppressMessages(library(plant))
rain <- as.numeric(Sys.getenv("RAIN", "100")); fac <- as.numeric(Sys.getenv("FAC", "100"))
life <- as.numeric(Sys.getenv("LIFE", "0.2"))
env <- Environment("TF24")
env$set_soil_water_state(rep(0.38, 5))
env$extrinsic_drivers_set_constant("rainfall", rain)
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- life
p <- add_strategies(p, trait_matrix(0.32, "lma"))
p$node_schedule_times <- list(c(0, life / 4, life / 2))
ctl <- control()
ctl$ode_tol_factor_soil <- fac; ctl$ode_tol_factor_max <- fac
types <- plant:::extract_RcppR6_template_types(p, "Parameters")
scm <- do.call(plant:::SCM, types)(p, env, events_default(p), ctl)
scm$record_trajectory <- TRUE
scm$run()
rows <- scm$store_trajectory()
tt <- vapply(rows, `[[`, 0, "time")
th1 <- vapply(rows, function(r) r$state[length(r$state) - 9], 0)
keep <- c(TRUE, diff(tt) > 0); tt <- tt[keep]; th1 <- th1[keep]
probe <- Environment("TF24")
probe$extrinsic_drivers_set_constant("rainfall", rain)
rate1 <- function(th) { probe$set_soil_water_state(c(th, rep(0.38, 4))); probe$compute_rates(rep(0, 5)); probe$soil$rates[1] }
mu <- vapply(th1, function(th) (rate1(th + 1e-7) - rate1(th - 1e-7)) / 2e-7, 0)
h <- diff(tt); z <- h * abs(mu[-length(mu)])
cat(sprintf("rain %g fac %g: %d steps, max z %.2f, steps with z > 3.73: %d, theta1 %.4f-%.4f, max |dtheta1| %.4f\n",
            rain, fac, length(h), max(z), sum(z > 3.7343), min(th1[-1]), max(th1), max(abs(diff(th1[-(1:5)])))))
