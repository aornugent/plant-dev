# Height against birth date after three years, nodes every two days, on
# episodic and dry: does episodic's rare heavy rain step the founders' heights
# between pulses, where linear interpolation between a rung's nodes misses?
#   PLANT_LIB=... Rscript docs/measurements/node-rule/episodic_heights.R   # from plant-dev's root
local({
  source("harness/long_drought.R")
})
for (rec in c("episodic", "dry")) {
  scen <- sprintf("%s, seed %d", rec, RAIN_SPECS[[rec]]$seed)
  RAIN_SPECS[[scen]] <- RAIN_SPECS[[rec]]
  times <- seq(0, 2.5, by = 2 / 365)
  p <- stand_at(times)
  p$max_patch_lifetime <- 3
  ct <- control_tf24(3e-5, Control(node_density_in_birth_date = TRUE, ode_split_sign_changes = TRUE))
  ct$ode_soil_alone_share <- 0.1
  scm <- run_scm(p, mkenv(scen), ct)
  sp <- scm$patch$species[[1]]
  h <- matrix(sp$ode_state, ncol = sp$size, dimnames = list(sp$new_node$ode_names))["height", ]
  b <- sp$node_times
  # The error of linear interpolation from every 34 days (u429's spacing) and
  # every 135 days (u108's), against the fine profile.
  miss <- function(step) {
    k <- seq(1, length(b), by = step)
    hl <- approx(b[k], h[k], xout = b, rule = 2)$y
    inside <- b <= max(b[k])
    mean(abs(hl[inside] - h[inside]) / h[inside])
  }
  jumps <- abs(diff(log(h)))
  rain <- rain_record(rec)[1:(3 * 365)]
  cat(sprintf("%-9s: wet days in 2.5 years %d; the first node's height at 3 years %.5f m; ln height node to node (2 days): median %.4f, largest %.3f; linear interpolation's mean relative miss from every 34 days %.4f, every 68 %.4f, every 135 %.4f\n",
              rec, sum(rain[1:913] > 0), h[1], median(jumps), max(jumps), miss(17), miss(34), miss(68)))
}
