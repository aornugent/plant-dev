# One stand forward pass at century scale, for scripts/profile-gradient.sh to
# sample. The gradient's half is profile-stand-gradient.R; this script runs no
# census and no sweep, so every sample in it is the forward model.
#
# Century scale for the reason the gradient script gives: the field build is
# O(knots x cohorts), so a short fixture understates anything that scales with
# cohort count.
#
# The schedule arrives as plain vectors rather than as a saved Parameters, and
# that is what lets two plant versions do the same work. A Parameters saved by
# one plant is readable by another only while its member list has not moved --
# refined-century.rds predates ode_step_sizes, and a current plant reading it
# stops at `Index out of bounds: [index='ode_step_sizes']`. Vectors transplant
# onto a Parameters built natively by whichever plant is loaded.
#
# `library`, not `pkgload::load_all`. load_all maps its own copy of plant.so and
# unlinks it while it is still mapped, so the profile's maps entry reads
# "plant.so (deleted)" and no archived copy can be substituted for it.
library(odelia)
library(plant)

sched_file <- Sys.getenv("PLANT_PROFILE_SCHEDULE",
                         "scripts/forward-century-schedule.rds")
# Recording the trajectory is what a later sweep walks, and it exists on only
# some of the versions this script is pointed at. Off by default so the number
# is the forward model alone.
record <- nzchar(Sys.getenv("PLANT_PROFILE_RECORD"))
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

cat("plant_lib         ", dirname(system.file(package = "plant")), "\n")
cat("max_patch_lifetime", p$max_patch_lifetime, "\n")
cat("nodes             ", length(p$node_schedule_times[[1]]), "\n")
cat("record_trajectory ", record, "\n")

# The schedule is transplanted rather than refined, so there is nothing to warm.
if (nzchar(Sys.getenv("PLANT_PROFILE_PREPARE"))) {
  quit(save = "no")
}

# run_scm gained record_trajectory and lost use_ode_times, so the call is built
# from whichever signature is loaded rather than written twice.
args <- list(p, Environment("TF24"), ctrl, refine_schedule = FALSE,
             collect = FALSE)
if ("record_trajectory" %in% names(formals(run_scm))) {
  args$record_trajectory <- record
} else if (record) {
  stop("this plant has no record_trajectory")
}

for (i in seq_len(reps)) {
  t_fwd <- system.time(scm <- do.call(run_scm, args))[["elapsed"]]
  cat("species           ", scm$patch$size, "\n")
  cat("ode_size          ", scm$patch$ode_size, "\n")
  cat("steps             ", length(scm$ode_times) - 1L, "\n")
  cat("forward_s         ", round(t_fwd, 2), "\n")
  flush(stdout())
}
