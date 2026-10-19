# plant-115 mechanism data: one real Cash-Karp step that spans several rain
# knots, from the synthetic record's stand (harness/long_drought.R, 108
# introductions, birth date, ode_tol 1e-4, no stops, uptake fraction 0) on B105.
# Picks the step with the most knots inside it among steps where the rain is
# not zero throughout; writes the step's knots, stage times, soil substep ends
# and the rain the model reads over it.  PLANT_LIB=<B105> Rscript step-run.R
source("/home/user/plant-dev/harness/long_drought.R")
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-115"
p <- stand_at(uniform_times(108))
ctrl <- Control(node_density_in_birth_date = TRUE, ode_tol_rel = 1e-4, ode_tol_abs = 1e-4)
env <- mkenv()
scm <- run_scm(p, env, ctrl)
tt <- scm$ode_times; hh <- scm$ode_step_sizes; ends <- scm$ode_soil_substep_ends
stopifnot(length(ends) == length(tt))
# ends[[k]] belongs to the step that reached tt[k], from tt[k-1], as fractions
# of that step.
k_in <- vapply(seq_along(tt)[-1], function(k) sum(AK > tt[k - 1] & AK < tt[k]), 0)
wet <- vapply(seq_along(tt)[-1], function(k) {
  x <- seq(tt[k - 1], tt[k], length.out = 50); max(env$extrinsic_drivers_evaluate_range("rainfall", x)) > 0.5 }, TRUE)
cand <- which(wet & k_in >= 3 & k_in <= 6 & lengths(ends[-1]) > 0)
k <- cand[which.max(k_in[cand])] + 1
t0 <- tt[k - 1]; h <- tt[k] - t0
cat(sprintf("steps %d, %d span a knot, %d substepped; chosen step %d: t0 %.6f yr, h %.3f d, %d knots, %d substep ends, recorded size %.6g\n",
            length(tt) - 1, sum(k_in > 0), sum(lengths(ends[-1]) > 0), k, t0, 365 * h, k_in[k - 1],
            length(ends[[k]]), hh[k]))
ck <- c(0, 1/5, 3/10, 3/5, 1, 7/8)
x <- seq(t0 - 0.1 * h, t0 + 1.1 * h, length.out = 600)
out <- rbind(
  data.frame(kind = "rain", t = x, value = pmax(0, env$extrinsic_drivers_evaluate_range("rainfall", x))),
  data.frame(kind = "knot", t = AK[AK > t0 - 0.1 * h & AK < t0 + 1.1 * h], value = NA),
  data.frame(kind = "stage", t = t0 + ck * h, value = seq_along(ck)),
  data.frame(kind = "substep_end", t = t0 + ends[[k]] * h, value = ends[[k]]))
out$day <- (out$t - t0) * 365
write.csv(out, file.path(here, "step-run.csv"), row.names = FALSE)
