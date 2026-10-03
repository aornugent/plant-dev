# The node state layout and the newborn's height, for the ordering check.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile/sp_common.R")
cfg <- config(1, 0L)
scm <- build_scm(cfg$times, cfg$lifetime, stops = cfg$stops)
scm$record_trajectory <- TRUE
scm$run()
sp <- scm$patch$species[[1]]
cat("node ode_names:", paste(sp$new_node$ode_names, collapse = ","), "\n")
cat("species size", sp$size, " species ode_state length", length(sp$ode_state),
    " patch ode_state", length(scm$patch$ode_state), "\n")
cat("new_node height:", tryCatch(sp$new_node$height, error = function(e) conditionMessage(e)), "\n")
cat("node heights:", tryCatch(paste(signif(sp$heights, 4), collapse = " "),
                              error = function(e) conditionMessage(e)), "\n")
st <- scm$patch$ode_state
cat("first 20 of patch state:", paste(signif(head(st, 20), 4), collapse = " "), "\n")
