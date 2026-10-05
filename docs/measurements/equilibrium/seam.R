# The three calls regnans's plant harness makes (traitecoevo/regnans 56ad241,
# R/community_plant.R), against this plant. Each either fails at once or is a
# no-op, so nothing here runs a stand.
#   PLANT_LIB=... Rscript seam.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) ".")
  source(file.path(here, "..", "..", "..", "harness", "long_drought.R"))
})
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
try_call <- function(label, f) {
  r <- tryCatch({ f(); "ran" }, error = function(e) paste("error:", conditionMessage(e)))
  cat(sprintf("%s: %s\n", label, r))
}
ctrl <- control()
try_call("ctrl$save_RK45_cache <- TRUE", function() ctrl$save_RK45_cache <- TRUE)
cat(sprintf("  and it reaches the Control a run takes: %s\n",
            "save_RK45_cache" %in% names(unclass(control()))))
try_call("run_scm(p, ctrl = ctrl, use_ode_times = FALSE)",
         function() run_scm(p, ctrl = control(), use_ode_times = FALSE))
ct <- control()
ct$node_density_in_birth_date <- TRUE
try_call("run_scm(p, ctrl = ct, refine_schedule = TRUE), birth-date coordinate",
         function() run_scm(p, ctrl = ct, refine_schedule = TRUE))
