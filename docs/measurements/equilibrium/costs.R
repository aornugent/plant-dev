# The reference analysis's cost in forward runs, from the unit costs measured at
# b* (eq.rds, replay.rds) and regnans's counts: a singular strategy found by a
# search in regnans's bounds, then classified. Wall-clock, on the 4-core machine
# every run here used. The assumptions are named below.
#   OUTD=... Rscript costs.R
outd <- Sys.getenv("OUTD")
x <- readRDS(file.path(outd, "eq.rds"))
F <- x$phases$stand_at_b_star$secs
W <- x$phases$walk_1$secs / F
Sw <- x$phases$invader_sweep$secs / F
Sr <- x$phases$stand_sweep$secs / F
r <- readRDS(file.path(outd, "replay.rds"))$runs
Fp <- r$replay$secs / r$adaptive$secs
m <- abs(x$equilibrium$multiplier)
cold <- x$equilibrium$runs
# A secant's error falls as f[n+1] = C f[n] f[n-1]; C from the measured run.
f <- x$runs[[1]]$f
fs <- vapply(x$runs[1:6], `[[`, 0, "f")
C <- abs(fs[3] / (fs[1] * fs[2]))
cat(sprintf("forward %.0f s; walk %.2f, invader sweep %.2f, stand sweep %.2f, replay %.2f; m %.3f; C %.4f\n",
            F, W, Sw, Sr, Fp, m, C))

# Runs to |f| < 1e-5 from |f0|: iterating b <- J(b), one run per contraction by m;
# a secant whose second point is a Newton step on the slope of the last solve.
iterate <- function(f0) ceiling(log(1e-5 / f0) / log(m)) + 1
secant <- function(f0) {
  e <- c(f0, C * f0^2)
  while (tail(e, 1) >= 1e-5) e <- c(e, C * e[length(e)] * e[length(e) - 1])
  length(e)
}
# Assumptions: ten candidates in one trait and fifteen in two, two in five far
# from the last; regnans's one-trait search starts each from b = 1e-3, which by
# iteration takes ln(b*/1e-3)/ln(R0) multiplying runs first; a near candidate
# starts 0.30 off (a 5% move in lma through the hyperparameterisation, whose
# elasticity is about 5.9); a perturbed resident 5.9e-3 off (regnans's step of
# 1e-3); regnans's classifier solves the singular resident's equilibrium again,
# from its own b*, which iteration confirms in one run and a record in another;
# every other design reuses it.
R0 <- exp(abs(f[1]))
climb <- ceiling(log(x$equilibrium$b_star / 1e-3) / log(R0))
near <- secant(0.30)
cat(sprintf("runs: cold secant %d; near secant %d; iteration from b = 1e-3 %d, from 0.30 %d, from 5.9e-3 %d\n",
            cold, near, climb + iterate(abs(f[1])), iterate(0.30), iterate(5.9e-3)))

cost <- function(k, design, cores = 1) {
  n <- if (k == 1) 10 else 15
  n_far <- round(0.4 * n)
  n_near <- n - n_far
  par <- function(members) ceiling(members / cores) # walk members side by side
  g_fd <- par(2 * k + 1) * W
  g_sw <- W + Sw
  h_fd <- par(1 + 4 * k^2) * W
  h_sw <- 2 * k * g_sw
  jac_sides <- ceiling(2 * k / min(cores, 2 * k))
  switch(design,
    regnans = n * (climb + iterate(abs(f[1])) + 1 + g_fd) +
      (2 + g_fd) + h_fd + 2 * k * (iterate(5.9e-3) + 1 + g_fd),
    floor = n_far * (cold + g_fd) + n_near * (near + g_fd) +
      h_fd + jac_sides * (2 + g_fd),
    grid = n_far * (cold + g_fd) + n_near * (near * Fp + g_fd) +
      h_fd + jac_sides * (2 * Fp + g_fd),
    grid_jacobian_only = n_far * (cold + g_fd) + n_near * (near + g_fd) +
      h_fd + jac_sides * (2 * Fp + g_fd),
    floor_sweeps = n_far * (cold + g_sw) + n_near * (near + g_sw) +
      h_sw + Sr + jac_sides * (1 + g_sw))
}
rows <- list(c("regnans", 1), c("floor", 1), c("floor", 4), c("grid", 1),
             c("grid_jacobian_only", 1), c("floor_sweeps", 1))
tab <- t(sapply(rows, function(r) sapply(1:2, function(k) cost(k, r[1], as.numeric(r[2])))))
dimnames(tab) <- list(sapply(rows, function(r) sprintf("%s, %s core%s", r[1], r[2],
                                                        if (r[2] == "1") "" else "s")),
                      c("k = 1", "k = 2"))
print(round(tab, 1))
cat(sprintf("\nhours at %.0f s a forward:\n", F))
print(round(tab * F / 3600, 1))
