# One stand gradient at century scale, for scripts/profile-gradient.sh to sample.
#
# Century scale on purpose. docs/leaf-rows-cost.md section 3 warns that a short
# fixture's shares mislead: the field build is O(knots x cohorts), so anything
# scaling with cohort count is understated by a short run, and so is the ratio
# itself. This is the fixture that document's table was taken on, so the numbers
# it produces replace those numbers rather than sitting beside them.
#
# THE SCHEDULE IS REFINED IN A SEPARATE PROCESS, and this is not tidiness.
# Refinement bisects on trait-dependent errors and re-runs the whole model many
# times -- 206 s against a 30 s run at century scale -- so a profile that includes
# it spends half its samples in the forward model and reads as if the reverse pass
# were cheap. It also makes the gradient-to-run ratio look far better than it is,
# because the denominator is then many runs rather than one. The refined parameters
# are cached beside this script's output; delete the cache to re-refine.
#
# The counts printed here are the other half of `share = count x price`. They come
# from the model's own counter, not from the profile, because a profile at -O2
# cannot say how many times anything ran.
#
# `library`, not `pkgload::load_all`. load_all maps its own copy of plant.so and
# unlinks it while it is still mapped, so the profile's maps entry reads
# "plant.so (deleted)" and no archived copy can be substituted for it.
library(odelia)
library(plant)

cache <- Sys.getenv("PLANT_PROFILE_CACHE", "refined-century.rds")
# The harness runs this script twice: once to refine, in a process with no
# profiler attached, and once to measure. Refining costs many model runs, so it
# must not be sampled and must not be paid twice -- this mode stops as soon as the
# schedule is cached, before any gradient.
prepare_only <- nzchar(Sys.getenv("PLANT_PROFILE_PREPARE"))

tr <- c(lma = 0.0825, hmat = 5.13, k_I = 0.5, a_l1 = 5.44, a_l2 = 0.306)
ctrl <- Control(node_density_in_birth_date = TRUE)

if (file.exists(cache)) {
  p <- readRDS(cache)
  cat("schedule          cached\n")
} else {
  p <- scm_base_parameters("TF24")
  p <- add_strategies(p, trait_matrix(unname(tr), names(tr)),
                      hyperpar = TF24_hyperpar, birth_rate = list(1.10))
  refined <- run_scm(p, Environment("TF24"), ctrl,
                     refine_schedule = TRUE, collect = FALSE)
  p <- refined$parameters
  saveRDS(p, cache)
  cat("schedule          refined and cached\n")
  if (!prepare_only) {
    # Reached only if this script is run by hand rather than through the harness,
    # so the refinement is in these samples. Say so rather than let the shares be
    # read as the gradient's.
    cat("WARNING           these samples include the refinement\n")
  }
}
if (prepare_only) {
  quit(save = "no")
}

cat("max_patch_lifetime", p$max_patch_lifetime, "\n")

scm <- run_scm(p, Environment("TF24"), ctrl,
               refine_schedule = FALSE, collect = FALSE)
# Keep the states the sweep needs. Without this the gradient repeats the whole
# forward run to recover them, and the profile charges that repeat to the
# gradient -- which is where the 8.5% in store_trajectory came from.
scm$record_trajectory <- TRUE
scm$reset()
t_fwd <- system.time(scm$run())[["elapsed"]]

cat("species           ", scm$patch$size, "\n")
cat("ode_size          ", scm$patch$ode_size, "\n")
cat("steps             ", length(scm$ode_times) - 1L, "\n")
cat("forward_s         ", round(t_fwd, 2), "\n")
flush(stdout())

# `:::` because the ladder's exports are compiled into the package but not in its
# NAMESPACE, so an installed plant does not expose them by name.
t_grad <- system.time(
  counts <- plant:::ladder_boundary_evaluations_tf24(scm))[["elapsed"]]

cat("gradient_s        ", round(t_grad, 2), "\n")
cat("ratio             ", round(t_grad / t_fwd, 1), "\n")
cat("rate_evaluations  ", counts$evaluations, "\n")
cat("metrics           ", counts$metrics, "\n")
cat("swept_ranges      ", scm$adjoint_segments, "\n")
