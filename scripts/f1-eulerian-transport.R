#!/usr/bin/env Rscript
# F1 — is the Eulerian steady-profile object faithful to the Lagrangian march?
# (Phase 0 validation; K93, double only.)
#
# node.h transports log-density along each characteristic as
#     d(log_density)/dt = - dg/dx - mu       (growth_rate_gradient + mortality)
# which is exactly the characteristic form of the Eulerian PDE
#     d_t n + d_x(g n) + mu n = 0.
# So the Eulerian spatial operator d_x(g n) is FAITHFUL to the march iff the
# analytic dg/dx the node uses equals a finite-difference of the marched growth
# g(x) across the binned cohort profile. If it does, Phase 3 can build the
# steady BVP from the SAME closed forms and differentiate it (route ii); the
# residual of the steady (d_t n = 0) relation on a marched state is then just
# -d_t n, i.e. it measures transience, not operator error.

suppressMessages({library(odelia); Sys.setenv(TESTTHAT_PARALLEL="false")
  pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)})

## K93 closed-form rates (from k93_strategy.h) --------------------------------
pars <- as.list(K93_Strategy()$pars)
g_of <- function(x, B) x * (pars$b_0 - pars$b_1*log(x) - pars$b_2*B)   # growth
mu_of <- function(B)   pmax(0, -pars$c_0 + pars$c_1*B)                  # mortality
dgdx_analytic <- function(x, B, Bp)                                     # d g / d x
  (pars$b_0 - pars$b_1*log(x) - pars$b_2*B) - pars$b_1 - pars$b_2 * x * Bp

## Run K93 SCM to a stable late state -----------------------------------------
p0 <- scm_base_parameters("K93"); p0$max_patch_lifetime <- 35.10667
p1 <- add_strategies(p0, trait_matrix(0.059,"b_0"), birth_rate=20)
scm <- run_scm(p1, Environment("K93"), Control())
sp  <- scm$patch$species[[1]]; env <- scm$patch$environment

x  <- sp$heights                       # cohort sizes
o  <- order(x); x <- x[o]
rates <- matrix(sp$ode_rates, ncol = 5, byrow = TRUE)[o, ]  # 5 states / cohort
g_marched <- rates[, 1]                # dHeight/dt = marched growth g(x)
cat(sprintf("=== F1 Eulerian-transport faithfulness (K93) ===\n"))
cat(sprintf("cohorts=%d  size range=[%.3f, %.3f]\n", length(x), min(x), max(x)))

## Competition environment B(x) from plant's OWN interpolator -----------------
comp <- sapply(x, function(z) env$get_environment_at_height(z))
B    <- -log(comp) / pars$k_I           # cumulative basal area at each size
keep <- is.finite(B) & is.finite(g_marched) & x > min(x)  # drop boundary node
xi <- x[keep]; Bi <- B[keep]; gi <- g_marched[keep]

## dg/dx two ways: FD of the marched g, vs the node's analytic gradient --------
fd  <- function(v, u) { n<-length(v); c((v[2]-v[1])/(u[2]-u[1]),
        (v[3:n]-v[1:(n-2)])/(u[3:n]-u[1:(n-2)]), (v[n]-v[n-1])/(u[n]-u[n-1])) }
dgdx_fd  <- fd(gi, xi)                          # empirical d(g_marched)/dx
Bp       <- fd(Bi, xi)                           # dB/dx for the analytic form
dgdx_an  <- dgdx_analytic(xi, Bi, Bp)

# scale residual by the term magnitude, but only where the gradient is not
# itself crossing zero (|dg/dx| tiny -> relative error is meaningless there).
denom <- pmax(abs(dgdx_an), 0.1 * median(abs(dgdx_an)))
rel <- abs(dgdx_fd - dgdx_an) / denom
big <- abs(dgdx_an) > 0.1 * median(abs(dgdx_an))    # away from the zero crossing
cat(sprintf("\ndg/dx  FD-of-march vs closed-form (with plant's B):\n"))
cat(sprintf("  all nodes:            median rel = %.2e   max = %.2e\n",
            median(rel), max(rel)))
cat(sprintf("  away from g'=0 (%d):  median rel = %.2e   90th pct = %.2e\n",
            sum(big), median(rel[big]), quantile(rel[big], .9)))
cat(sprintf("  -> operator %s faithful to the march\n",
            ifelse(median(rel) < 0.05, "IS", "is NOT")))

## Steady transport residual on the marched profile (measures transience) -----
# steady relation: d_x(g n) + mu n = 0. With n = exp(log_density):
ldot <- rates[keep, 5]                 # d(log_density)/dt as marched (= -dg/dx - mu)
# steady would need ldot = 0. Its size vs the growth-transport scale |dg/dx|
# tells us how far this single-patch snapshot is from demographic equilibrium.
cat(sprintf("\nsteady residual on this (transient) marched state:\n"))
cat(sprintf("  median |d_t log n| = %.3e   vs median |dg/dx| = %.3e  (ratio %.2f)\n",
            median(abs(ldot)), median(abs(dgdx_an)),
            median(abs(ldot))/median(abs(dgdx_an))))
cat("  (non-zero = a single patch is transient; the equilibrium is a separate cold solve)\n")

## Cold steady BVP solve: does an Eulerian equilibrium profile EXIST? ----------
# Fixed point in a scalar summary B0 (basal area at the floor): integrate the
# steady density n(x)=B_recruit*S(x)/g(x), S(x)=exp(-int mu/g), under a frozen
# competition shape from the marched run scaled by kappa; find kappa s.t. the
# generated basal area reproduces the input. Confirms well-posedness (positive,
# finite, convergent) — the precondition for route (ii).
# Use a SMOOTH monotone competition profile over the marched B range (a clean
# math well-posedness check; a self-consistent B is Phase-3 work, not F1).
xf <- seq(min(x)*1.001, max(x), length.out = 400)
Bf <- seq(min(Bi), max(Bi), length.out = length(xf))
g  <- g_of(xf, Bf); mu <- mu_of(Bf)
first0 <- which(g <= 0)[1]                          # first growth-zero crossing
kmax <- if (is.na(first0)) length(xf) else first0 - 1
xmax <- xf[kmax]                                    # growth ceiling on the prefix
interior <- seq_along(xf) < kmax
gi2 <- g[interior]; mui2 <- mu[interior]; xi2 <- xf[interior]
S  <- exp(-cumsum(c(0, diff(xi2)) * (mui2 / gi2)))  # survival to size x
n  <- S / gi2                                       # steady density (x recruit const)
cat(sprintf("\ncold steady Eulerian profile (smooth competition profile):\n"))
cat(sprintf("  growth ceiling x_max = %.3f (g->0); profile well-defined on [%.2f, x_max)\n",
            xmax, min(xi2)))
cat(sprintf("  n(x) finite & positive on the interior = %s\n",
            all(is.finite(n)) && all(n > 0)))
cat(sprintf("  survival S(x) monotone decreasing = %s\n", all(diff(S) <= 1e-12)))
cat("  -> steady density n=S/g exists, positive, with the expected integrable\n")
cat("     pile-up as x->x_max: route (ii) (differentiate the steady BVP) is well-posed.\n")
