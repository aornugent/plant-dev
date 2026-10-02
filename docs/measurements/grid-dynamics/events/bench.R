# What one single-member evaluation costs against one whole-patch evaluation, at
# states of the tied run at 1e-4 with 20, 40, 60, 80 and 100 members: the field
# build (light profile, boundary node) is paid by both, the other members' leaf
# solves only by the whole one. Also times the field build alone.
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events"
Sys.setenv(PLANT_LIB = file.path(E, "lib"), NODES = "108", TOL = "1e-4", ATOL = "1e-4", METHOD = "ck")
source(file.path(E, "harness", "ark_prototype.R"))
sizes <- c(20, 40, 60, 80, 100)
sv$t <- 0; sv$h_last <- ct$ode_step_size_initial; sv$zone_until <- -Inf; sv$Pdot <- numeric()
reps <- 300
time_it <- function(f) { t0 <- proc.time()[["elapsed"]]; for (i in seq_len(reps)) f(); (proc.time()[["elapsed"]] - t0) / reps }
for (k in seq_along(times)) {
  patch$introduce_new_node(1L, times[k])
  sv$y <- patch$ode_state
  sv$dydt <- rates(sv$y, sv$t)
  sv$P <- production(sv$y); sv$Pdot <- c(sv$Pdot, 0)[seq_along(sv$P)]; sv$K <- klass(sv$y)
  if (k %in% sizes) {
    y <- sv$y; t <- sv$t; M <- k; j <- max(1, M %/% 2)
    full <- time_it(function() patch$derivs(y, t))
    one <- time_it(function() plant:::patch_node_rates_tf24(patch, y, t, 1L, j))
    field <- time_it(function() patch$set_ode_state(y, t))
    s0 <- leaf_solves(); invisible(patch$derivs(y, t)); lf <- leaf_solves() - s0
    s0 <- leaf_solves(); invisible(plant:::patch_node_rates_tf24(patch, y, t, 1L, j)); lo <- leaf_solves() - s0
    cat(sprintf("t %6.2f, %3d members: whole %.3f ms (%d leaf solves), single %.3f ms (%d), state and field alone %.3f ms; single/whole %.3f, leaf-solve ratio %.3f\n",
                t, M, 1e3 * full, lf, 1e3 * one, lo, 1e3 * field, one / full, lo / lf))
    sv$dydt <- rates(sv$y, sv$t)
  }
  if (k == max(sizes)) break
  t_end <- times[k + 1]
  for (target in c(pulses[pulses > sv$t & pulses < t_end], t_end)) {
    while (sv$t < target) step(target)
  }
}
