# One stand gradient at century scale, on the fixture profile-stand-forward.R
# uses, so the two numbers divide. The forward half is that script; this one adds
# the census and the sweep.
#
# The schedule arrives as plain vectors for the reason given there: a Parameters
# saved by one plant is readable by another only while its member list has not
# moved.
#
# THE FORWARD RUN IS TIMED APART FROM THE SWEEP, and the split is the point. A
# sweep needs the state at every accepted step; a plant that can keep them takes
# record_trajectory and the sweep reads them, and a plant that cannot repeats the
# whole model to recover them -- so the same sweep is charged an extra forward run
# on one side and not on the other. Reading gradient_s alone across those two
# would price a deletion as a speed-up.
library(odelia)
library(plant)

sched_file <- Sys.getenv("PLANT_PROFILE_SCHEDULE",
                         "scripts/forward-century-schedule.rds")
reps <- as.integer(Sys.getenv("PLANT_PROFILE_REPS", "1"))

tr <- c(lma = 0.0825, hmat = 5.13, k_I = 0.5, a_l1 = 5.44, a_l2 = 0.306)
ctrl <- Control(node_density_in_birth_date = TRUE)

p <- scm_base_parameters("TF24")
p <- add_strategies(p, trait_matrix(unname(tr), names(tr)),
                    hyperpar = TF24_hyperpar, birth_rate = list(1.10))
sched <- readRDS(sched_file)
p$max_patch_lifetime  <- sched$max_patch_lifetime
p$node_schedule_times <- sched$node_schedule_times
p$ode_times           <- sched$ode_times

keeps <- "record_trajectory" %in% names(formals(run_scm))
cat("plant_lib         ", dirname(system.file(package = "plant")), "\n")
cat("keeps_states      ", keeps, "\n")

if (nzchar(Sys.getenv("PLANT_PROFILE_PREPARE"))) {
  quit(save = "no")
}

args <- list(p, Environment("TF24"), ctrl, refine_schedule = FALSE,
             collect = FALSE)
if (keeps) args$record_trajectory <- TRUE

for (i in seq_len(reps)) {
  t_fwd <- system.time(scm <- do.call(run_scm, args))[["elapsed"]]
  cat("steps             ", length(scm$ode_times) - 1L, "\n")
  cat("forward_s         ", round(t_fwd, 2), "\n")
  flush(stdout())

  # `:::` because the ladder's exports are compiled into the package but not in
  # its NAMESPACE, so an installed plant does not expose them by name.
  t_grad <- system.time(
    counts <- plant:::ladder_boundary_evaluations_tf24(scm))[["elapsed"]]
  cat("gradient_s        ", round(t_grad, 2), "\n")
  cat("ratio             ", round(t_grad / t_fwd, 1), "\n")
  cat("rate_evaluations  ", counts$evaluations, "\n")
  cat("metrics           ", counts$metrics, "\n")
  # Placements and the swept ranges are only on the plants that report them;
  # named here rather than assumed so an older one prints NA instead of stopping.
  cat("placements        ",
      if (is.null(counts$placements)) NA else counts$placements, "\n")
  # The range count moved onto the gradient's own return, so prefer it there and
  # keep the two older spellings for the plants this script is also pointed at.
  seg <- if (!is.null(counts$segments)) counts$segments else
    tryCatch(plant:::census_adjoint_segments_tf24(scm),
             error = function(e) scm$adjoint_segments)
  cat("swept_ranges      ", if (is.null(seg)) NA else seg, "\n")
  # A refused sweep costs what an accepted one costs, so a timing without this is
  # the price of an answer that was discarded.
  cat("refusal           ",
      if (is.null(counts$refusal)) "unreported"
      else if (nzchar(counts$refusal)) counts$refusal else "none", "\n")
  flush(stdout())
}
