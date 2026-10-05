# The reference analysis's cost in forward runs, from the unit costs measured at
# b* (eq.rds, replay.rds) and regnans's counts: a singular strategy found by a
# search, then classified. The split of candidates into cold and warm, the warm
# equilibrium's runs and a candidate's first offset are assumptions, named below.
#   OUTD=... Rscript costs.R
outd <- Sys.getenv("OUTD")
x <- readRDS(file.path(outd, "eq.rds"))
F <- x$phases$stand_at_b_star$secs
W <- x$phases$walk_1$secs / F
Sw <- x$phases$invader_sweep$secs / F
Sr <- x$phases$stand_sweep$secs / F
rp <- file.path(outd, "replay.rds")
Fp <- if (file.exists(rp)) {
  r <- readRDS(rp)$runs
  r$replay$secs / r$adaptive$secs
} else 71 / 86
m <- abs(x$equilibrium$multiplier)
cold <- x$equilibrium$runs
iterate <- function(f0) ceiling(log(1e-5 / f0) / log(m)) + 1
f_b1 <- abs(x$runs[[1]]$f)
cat(sprintf("forward %.0f s; walk %.2f, invader sweep %.2f, stand sweep %.2f, replay %.2f forwards; m %.3f\n",
            F, W, Sw, Sr, Fp, m))

# Assumptions: a search makes 10 candidates in one trait and 15 in two, two in
# five outside any radius; a warm equilibrium takes 3 runs; a warm candidate
# starts 0.4 off in ln J - ln b (a 5% move at an elasticity of 8), and a
# perturbed resident 8e-3 (regnans's relative step of 1e-3).
warm_runs <- 3
cost <- function(k, design) {
  n <- if (k == 1) 10 else 15
  n_cold <- round(0.4 * n)
  n_warm <- n - n_cold
  g_fd <- (2 * k + 1) * W
  g_sw <- W + Sw
  h_fd <- (1 + 4 * k^2) * W
  h_sw <- 2 * k * g_sw
  switch(design,
    regnans = n_cold * (iterate(f_b1) + 1 + g_fd) + n_warm * (iterate(0.4) + 1 + g_fd) +
      h_fd + 2 * k * (iterate(8e-3) + 1 + g_fd),
    floor = n_cold * (cold + g_fd) + n_warm * (warm_runs + g_fd) +
      h_fd + 2 * k * (warm_runs + g_fd),
    grid = n_cold * (cold + g_fd) + n_warm * (warm_runs * Fp + g_fd) +
      h_fd + 2 * k * (2 * Fp + g_fd),
    grid_sweeps = n_cold * (cold + g_sw) + n_warm * (warm_runs * Fp + g_sw) +
      h_sw + Sr + 2 * k * (Fp + g_sw))
}
designs <- c("regnans", "floor", "grid", "grid_sweeps")
tab <- sapply(1:2, function(k) sapply(designs, cost, k = k))
colnames(tab) <- c("k = 1", "k = 2")
print(round(tab, 1))
cat(sprintf("\nhours at %.0f s a forward:\n", F))
print(round(tab * F / 3600, 1))
