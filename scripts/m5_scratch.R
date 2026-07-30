#   PLANT_M5_ARM=0 Rscript scripts/m5_scratch.R      # and arms 1, 2
#
# M5. What the transport stencil's mutable copy should be.
#
# growth_rate_gradient finite-differences growth by perturbing height, which
# needs an Individual to perturb. develop holds a `thread_local
# std::optional<individual_type>` for it. Under a templated Strategy that is a
# thread_local holding active values across block tape lifetimes -- the class of
# fault that segfaults far from its cause -- so the plan removes it, and the
# question is what the pure-double path should keep. Three arms:
#
#   0  develop's thread_local scratch
#   1  a Node member (mutable), so the storage is per node rather than per
#      thread: 141 of them at production, and it is copied when nodes are
#      copied, which is the cost against the cache locality
#   2  a fresh copy per call, which is what the scratch exists to avoid
#
# Arms 1 and 2 need docs/reports/m5-scratch-arms.patch applied to the tree the
# probe loads; without it PLANT_M5_ARM is unread and every arm measures arm 0.
#
# CONFIGURATION. plant develop 141dc8df plus that patch, odelia 854a8e18, built
# -O2 -DNDEBUG via pkgbuild::compile_dll(debug = FALSE). One TF24 strategy at
# lma 0.1978791, Environment("TF24"), Control(), refine_schedule = FALSE,
# max_patch_lifetime = 105.32 set on the base parameters before add_strategies,
# collect = FALSE so the timing is the solver's and not R's assembly. Absolute
# times belong to this machine; the ratio is what transfers.
#
# RESULTS. Three timed runs per arm after one untimed, and arm 0 repeated last to
# price the run-to-run spread.
#
#   arm            min       median      max
#   0 thread_local   86.14 s   86.23 s   88.67 s
#   1 Node member    87.61 s   88.00 s   88.68 s
#   2 fresh copy     87.59 s   88.35 s   89.26 s
#   0 again          86.81 s   87.88 s   89.92 s
#
# All four reproduce offspring 42.140173575095666 exactly, and every rep within an
# arm is identical, so the arms differ only in where the copy lives.
#
# The medians do not separate: arm 0 repeated lands at 87.88 s, inside arms 1 and
# 2. On min-of-three, which is the better estimator under this noise, arm 0 sits
# at 86.1-86.8 s and both others at 87.6 s -- so the effect is AT MOST ~1.5%, and
# 1.5% is inside the band P1.2 accepts. Read that as: none of the three is worth
# choosing on speed, including arm 2, which has no scratch at all. So the plan's
# fallback -- if one is needed, a Node member beats a thread_local -- is not
# needed: removing the thread_local costs nothing measurable and nothing has to
# replace it.
#
# Also measured, as probe craft rather than a result: collect = TRUE adds ~38 s of
# R-side assembly on top of the 86 s solve.

suppressMessages({ library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE) })
arm <- Sys.getenv("PLANT_M5_ARM", "0")

p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 105.32
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))

# One untimed run first: the first call pays page faults and any lazy setup that
# is not the arm's business.
invisible(run_scm(p, Environment("TF24"), Control(), collect = FALSE,
                  refine_schedule = FALSE))

reps <- 3L
secs <- numeric(reps); offspring <- numeric(reps)
for (i in seq_len(reps)) {
  t <- system.time(
    r <- run_scm(p, Environment("TF24"), Control(), collect = FALSE,
                 refine_schedule = FALSE))
  secs[i] <- t[["elapsed"]]
  offspring[i] <- sum(r$offspring_production)
}
cat(sprintf("arm %s   min %.2f s   median %.2f s   max %.2f s\n",
            arm, min(secs), median(secs), max(secs)))
cat(sprintf("arm %s   offspring %.17g   identical across reps: %s\n",
            arm, offspring[1], all(offspring == offspring[1])))
