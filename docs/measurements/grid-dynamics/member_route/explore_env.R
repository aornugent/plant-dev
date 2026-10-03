# What the environment copy costs, with the 41-year rainfall driver and with a
# short one, and the drivers a TF24 environment carries.
#   PLANT_LIB=$DEV/lib_guard Rscript explore_env.R
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/spike_methods"
D <- dirname(S)
source(file.path(S, "snap/harness/long_drought.R"))
times <- uniform_times(108)
p <- stand_at(times)
ct <- control()
ct$node_density_in_birth_date <- TRUE
tm <- function(f, n = 100) { t0 <- proc.time()[["elapsed"]]; for (i in seq_len(n)) f(); (proc.time()[["elapsed"]] - t0) / n * 1e3 }
e_full <- mkenv("long-drought")
cat("drivers:", paste(e_full$extrinsic_drivers_get_names(), collapse = ", "), "\n")
e_short <- Environment("TF24")
days <- seq(0, 30)
e_short$extrinsic_drivers_set_variable("rainfall", days / 365, rep(3, length(days)))
for (nm in c("full", "short")) {
  e <- if (nm == "full") e_full else e_short
  pa <- plant:::Patch("TF24", "TF24_Env")(p, e, ct)
  pa$introduce_new_node(1L, 0)
  cat(sprintf("%s rainfall: environment copy %.3f ms; Environment object copy via R6 %.3f ms\n", nm,
              tm(function() pa$environment), tm(function() pa$parameters)))
}
