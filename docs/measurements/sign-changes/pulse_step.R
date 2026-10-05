# Are the pairs the scan missed real? The step that opens the pulse on day 8684
# (scan.log: nodes 5, 6 and 7 dip below zero in its first fifth on the dense
# output). The split's program is replayed to the step's start; the step is then
# taken once by Cash-Karp, as odelia takes it, and net production read on its
# dense output at u = k/64; and the same day is integrated in 512 classical
# Runge-Kutta steps, net production read at each.
#   PLANT_LIB=... SC=... OUT=pulse_step.rds Rscript pulse_step.R
local({
  here <- "harness"
  source(file.path(here, "long_drought.R"))
})
SC <- Sys.getenv("SC")
scen <- sprintf("%s, seed %d", SCEN, RAIN_SPECS[[SCEN]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[SCEN]]
knots <- active_knots(scen)
times <- uniform_times(108)
program <- readRDS(file.path(SC, "runs", "program_split.rds"))$st
t0 <- 8684 / 365
i0 <- which.min(abs(program$time - t0))
stopifnot(abs(program$time[i0] - t0) < 1e-9)
h <- program$h[i0 + 1]
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- program$time[i0]
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times[times <= program$time[i0]])
p$ode_times <- c(0, program$time[seq_len(i0)])
p$ode_step_sizes <- c(NaN, program$h[seq_len(i0)])
ct <- control()
ct$ode_tol_rel <- 1e-4
ct$ode_tol_abs <- 1e-8
ct$node_density_in_birth_date <- TRUE
ct$ode_split_sign_changes <- TRUE
k <- sort(unique(knots))
ev <- events(events_default(p), pulse_rows(k[k <= program$time[i0]]))
scm <- run_scm(p, mkenv(scen), ct, events = ev)
patch <- scm$patch
y0 <- patch$ode_state
tt <- patch$time
cat(sprintf("step from t = %.9f (day %.4f), h = %.9g (%.4f d); patch at %.9f\n",
            program$time[i0], program$time[i0] * 365, h, h * 365, tt))
nodes <- c(5, 6, 7)
P_at <- function(y, t) {
  r <- patch$derivs(y, t)
  sp <- patch$species[[1]]
  list(rate = r, P = vapply(nodes, function(j) sp$nodes[[j]]$individual$aux("net_mass_production_dt"), 0))
}
ah <- c(1/5, 0.3, 3/5, 1, 7/8)
B <- list(c(1/5), c(3/40, 9/40), c(0.3, -0.9, 1.2), c(-11/54, 2.5, -70/27, 35/27),
          c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096))
cw <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
DW <- rbind(c(1, 0, 0, 0, 0, 0, 0),
            c(-156473/57792, 0, 1159825/332304, 14725/60544, 5301/38528, -202836/76153, 3/2),
            c(729889/260064, 0, -8030425/1495368, 290425/817344, -5301/19264, 493736/76153, -4),
            c(-24797/24768, 0, 2275475/996912, -19225/49536, 5301/38528, -3492/989, 5/2))
e0 <- P_at(y0, tt)
K <- list(e0$rate)
for (i in 1:5) {
  ys <- y0 + h * Reduce(`+`, Map(`*`, B[[i]], K[seq_len(i)]))
  K[[i + 1]] <- patch$derivs(ys, tt + ah[i] * h)
}
y1 <- y0 + h * Reduce(`+`, Map(`*`, cw, K))
e1 <- P_at(y1, tt + h)
Kd <- c(K, list(e1$rate))
dense <- function(u) {
  w <- colSums(DW * c(u, u^2, u^3, u^4))
  y0 + h * Reduce(`+`, Map(`*`, w, Kd))
}
u <- (0:64) / 64
Pd <- t(vapply(u, function(v) P_at(dense(v), tt + v * h)$P, numeric(length(nodes))))
N <- 512
y <- y0
Pf <- matrix(NA_real_, N + 1, length(nodes))
Pf[1, ] <- e0$P
for (n in 1:N) {
  t <- tt + (n - 1) * h / N
  dt <- h / N
  k1 <- patch$derivs(y, t)
  k2 <- patch$derivs(y + dt / 2 * k1, t + dt / 2)
  k3 <- patch$derivs(y + dt / 2 * k2, t + dt / 2)
  k4 <- patch$derivs(y + dt * k3, t + dt)
  y <- y + dt / 6 * (k1 + 2 * k2 + 2 * k3 + k4)
  Pf[n + 1, ] <- P_at(y, t + dt)$P
}
uf <- (0:N) / N
for (j in seq_along(nodes)) {
  cat(sprintf("node %d: dense output min %.4g at u = %.3f; 512 steps min %.4g at u = %.4f; start %.4g, end %.4g (dense) %.4g (512)\n",
              nodes[j], min(Pd[, j]), u[which.min(Pd[, j])], min(Pf[, j]), uf[which.min(Pf[, j])],
              Pd[1, j], Pd[65, j], Pf[N + 1, j]))
}
cat(sprintf("state at the step's end, Cash-Karp against 512 steps: max relative %.3g\n",
            max(abs(y1 - y) / pmax(abs(y), 1e-12))))
saveRDS(list(u = u, Pd = Pd, uf = uf, Pf = Pf, nodes = nodes, h = h, t0 = tt), Sys.getenv("OUT"))
