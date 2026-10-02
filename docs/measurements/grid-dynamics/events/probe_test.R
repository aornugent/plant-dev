# Patch::r_node_rates against the whole-patch evaluation, bit for bit: at
# states of a tied run at 1e-4 on long drought (the driver's own steps), for
# every member, the newest included, and at an interpolated state with one
# member's state moved as the split moves it. Also counts the leaf solves of
# one whole-patch and one single-member evaluation.
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events"
Sys.setenv(PLANT_LIB = file.path(E, "lib"), NODES = "108", TOL = "1e-4", ATOL = "1e-4", METHOD = "ck")
source(file.path(E, "harness", "ark_prototype.R"))
stopifnot(LEAF_COUNTS)
checks <- c(3.0, 3.6, 8.0, 12.5)
sv$t <- 0; sv$h_last <- ct$ode_step_size_initial; sv$zone_until <- -Inf; sv$Pdot <- numeric()
worst <- 0; tested <- 0; mismatches <- 0
probe_at <- function(y, t, label) {
  M <- (length(y) - 10) %/% 9
  full <- patch$derivs(y, t)
  aux <- patch$ode_aux
  s0 <- leaf_solves(); invisible(patch$derivs(y, t)); per_full <- leaf_solves() - s0
  for (j in seq_len(M)) {
    idx <- 9 * (j - 1) + 1:9
    s0 <- leaf_solves()
    r <- plant:::patch_node_rates_tf24(patch, y, t, 1L, j)
    per_one <- leaf_solves() - s0
    want <- c(full[idx], aux[13 * (j - 1) + 1:13])
    same <- identical(r, want)
    tested <<- tested + 1
    if (!same) {
      mismatches <<- mismatches + 1
      worst <<- max(worst, max(abs(r - want) / pmax(abs(want), 1e-300)))
    }
    if (j %in% c(1, M)) cat(sprintf("%s t %.4f member %d of %d: %s; leaf solves %d whole, %d single\n",
                                    label, t, j, M, if (same) "identical" else "DIFFERS", per_full, per_one))
  }
}
done <- FALSE
for (k in seq_along(times)) {
  patch$introduce_new_node(1L, times[k])
  sv$y <- patch$ode_state
  sv$dydt <- rates(sv$y, sv$t)
  sv$P <- production(sv$y); sv$Pdot <- c(sv$Pdot, 0)[seq_along(sv$P)]; sv$K <- klass(sv$y)
  t_end <- if (k < length(times)) times[k + 1] else LIFETIME
  for (target in c(pulses[pulses > sv$t & pulses < t_end], t_end)) {
    while (sv$t < target) {
      y_prev <- sv$y; f_prev <- sv$dydt; t_prev <- sv$t
      step(target)
      if (length(checks) && sv$t >= checks[1]) {
        probe_at(sv$y, sv$t, "accepted state")
        # an interpolated state inside the last step with member 1 moved as a
        # sub-step stage would move it
        h <- sv$t - t_prev; u <- 0.37
        y <- (1 + 2 * u) * (1 - u)^2 * y_prev + u * (1 - u)^2 * h * f_prev +
          u^2 * (3 - 2 * u) * sv$y + u^2 * (u - 1) * h * sv$dydt
        y[1:9] <- y[1:9] * (1 + 1e-3)
        probe_at(y, t_prev + u * h, "interpolated, member 1 moved")
        # the patch is left holding that state; put the step's back
        sv$dydt <- rates(sv$y, sv$t)
        checks <- checks[-1]
        if (!length(checks)) done <- TRUE
      }
      if (done) break
    }
    if (done) break
  }
  if (done) break
}
cat(sprintf("members tested %d, mismatches %d, largest relative difference %.3g\n", tested, mismatches, worst))
