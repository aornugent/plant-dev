# Each accepted state of the tol 1e-7 monolithic reference, re-evaluated: its
# time, soil, soil rates and per-layer uptake (tail(ode_aux, 5)), saved for the
# recorded-uptake and recorded-soil couplings.
#
#   PLANT_LIB=$DEV/split/lib NODES=108 Rscript record_uptake.R out.rds
Sys.setenv(METHOD = "ck")
source("/home/user/plant-dev/.claude/worktrees/agent-a4e5afe75b72479f0/harness/ark_prototype.R")
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/ark"
ref <- readRDS(file.path(D, "ck_u108_1e-7.rds"))
ref_t <- ref$st$time
ref_s <- readRDS(file.path(D, "ck_u108_1e-7_states.rds"))
n <- length(ref_t)
out <- list(time = ref_t, soil = matrix(NA_real_, n, 5), rate = matrix(NA_real_, n, 5),
            uptake = matrix(NA_real_, n, 5), M = integer(n))
# The initial state, with its rates, at t = 0.
k <- 0L
for (leg in seq_along(times)) {
  patch$introduce_new_node(1L, times[leg])
  if (leg == 1) {
    y0 <- patch$ode_state
    r0 <- patch$derivs(y0, 0)
    out$init <- list(time = 0, soil = y0[soil(y0)], rate = r0[soil(y0)], uptake = tail(patch$ode_aux, 5))
  }
  t_end <- if (leg < length(times)) times[leg + 1] else LIFETIME
  while (k < n && ref_t[k + 1] <= t_end + 1e-12) {
    k <- k + 1L
    y <- ref_s[[k]]
    stopifnot(length(y) == 9 * leg + 10)
    r <- patch$derivs(y, ref_t[k])
    out$soil[k, ] <- y[soil(y)]
    out$rate[k, ] <- r[soil(y)]
    out$uptake[k, ] <- tail(patch$ode_aux, 5)
    out$M[k] <- leg
  }
  # leave the patch at the leg's last state, so the next introduction copies it
}
stopifnot(k == n)
saveRDS(out, commandArgs(TRUE)[1])
cat(sprintf("recorded %d states; uptake range %.3g to %.3g\n", n, min(out$uptake), max(out$uptake)))
