#   Rscript scripts/m3_fixed_fractions.R
#
# M3, the accuracy half. Which state's refinement should supply the fixed knot
# fractions?
#
# P2.1 holds the light interpolant on u = z / height_max with fractions fixed for
# the run, which removes rescale_spline's carried knot set and makes the field a
# pure function of the state (build-plan section 2.6). Fixing them makes the
# choice of fractions load-bearing in a way develop's per-introduction refinement
# hides: develop re-refines at each of the 141 introductions and lands on 33 to
# 129 knots, so the set it uses at a seedling stand is not the set it uses under a
# closed canopy. Three candidates, and the plan leaves the choice open:
#
#   early     develop's own fractions at the first step, as u = x / height_max
#   mature    develop's own fractions at a mid-run step, the same way
#   uniform   equally spaced, at the run's mean knot count
#   union     every step's fractions pooled and deduped, which is the plan's
#             pilot-run candidate -- included to price what it costs in knots
#
# What is measured is the quantity the model consumes: each cohort's crown-mean
# light, integral of L(z) q(z,h) dz over [0, h], which after z = h xi is
# integral of L(h xi) 2 eta (1 - xi^eta) xi^(eta-1) dxi -- so the error is
# weighted the way the model weights it, rather than uniformly over the profile.
# The reference at each step is develop's own knot data for that step; a candidate
# is that same field resampled onto the candidate positions and re-interpolated.
# Both sides use one R spline routine, so what is compared is the KNOT SET and not
# two spline implementations. Bit-identity within an introduction interval is a
# statement about rescale_spline's map (x_k = u_k * height_max) and is not this
# probe's business.
#
# CONFIGURATION. plant develop 141dc8df, odelia 854a8e18, built -O2 -DNDEBUG via
# pkgbuild::compile_dll(debug = FALSE). One TF24 strategy at lma 0.1978791,
# Environment("TF24"), Control(), refine_schedule = FALSE, max_patch_lifetime =
# 105.32 set on the base parameters before add_strategies, collect = TRUE. eta =
# 12 and the crown quadrature is Gauss-Legendre 15, matching
# scripts/m1_moving_bound.cpp. 142 output times, 10 153 cohort records.
#
# RESULTS. develop's own sets run 33 to 129 knots, mean 58.4, over 142 steps.
# |candidate - develop| / develop in crown-mean light, over all 10 153 cohort
# records, plus the worst unweighted pointwise profile error:
#
#   set          knots     median        p95        max   max profile
#   early           33   2.533e-05  1.445e-03  8.446e-03    1.848e-02
#   mature         115   2.676e-08  5.488e-04  3.307e-03    1.821e-03
#   uniform         58   4.883e-06  2.147e-04  2.060e-03    4.578e-03
#   union          279   2.292e-10  4.920e-08  8.026e-07    6.588e-07
#   uniform         33   2.533e-05  1.445e-03  8.446e-03    1.848e-02
#   uniform         65   1.645e-06  1.883e-04  1.699e-03    3.281e-03
#   uniform        129   2.920e-09  2.458e-05  2.542e-04    5.615e-04
#   uniform        257   0.000e+00  8.095e-07  4.540e-05    9.274e-05
#
# Three things follow, and they answer a different question than the one asked.
#
#   The error is resolution, not placement. Doubling the uniform count divides the
#   worst crown-mean shift by 5.0, 6.7 and 5.6 -- about h^2.5, not the h^4 a cubic
#   gives on smooth data. That is the right rate for this field: L = exp(-A) and A
#   has a derivative break at every cohort height, because Q(z/h) kinks where
#   z = h. So the plan's failure signature for a bad set -- an error that does not
#   shrink with knot count -- does not appear, and adaptive refinement cannot fix
#   the rate either, since the kinks move with the state.
#
#   A refinement-derived set is not better than uniform at equal count, and can be
#   worse at higher count. uniform at 58 beats mature at 115 on every statistic.
#   And `early` reproduces uniform33 to every digit, because at the first step the
#   field is flat and develop's refiner returns an equally spaced set -- so
#   "refine at the first state" carries no information at all.
#
#   The union's 8.026e-07 is circular and should not be read as accuracy. It is a
#   superset of every reference knot (to the rounding this probe applies), so it
#   reproduces the reference nearly by construction. What it does price honestly is
#   the cost: 279 knots is 558 data numbers per stage, against 130 at 65 knots,
#   which would quadruple the cohort block's declared input vector.
#
# So the choice is a count, not a state: uniform fractions, with the count read off
# the re-blessing tolerance. 65 knots gives a worst-case crown-mean shift of
# 1.7e-03 and a median of 1.6e-06; 129 gives 2.5e-04 for twice the data.
#
# CAVEAT ON THE REFERENCE. develop's own knot data for each step, splined in R, is
# the reference, and a candidate is that field resampled onto the candidate
# positions. So these are shifts relative to develop -- which is what re-blessing
# needs -- and not accuracy against the true field. Both sides use one R spline
# routine, so the comparison isolates the knot set.

suppressMessages({ library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE) })

p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 105.32
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
r <- run_scm(p, Environment("TF24"), Control(), collect = TRUE, refine_schedule = FALSE)

eta <- TF24_Strategy()$pars$eta
la  <- r$env$light_availability
sp  <- r$species
steps <- sort(unique(la$step))

# Gauss-Legendre 15 on [0, 1], and the crown weight in xi.
gl_x <- c(-0.9879925180204854, -0.9372733924007060, -0.8482065834104272,
          -0.7244177313601701, -0.5709721726085388, -0.3941513470775634,
          -0.2011940939974345,  0.0,                 0.2011940939974345,
           0.3941513470775634,  0.5709721726085388,  0.7244177313601701,
           0.8482065834104272,  0.9372733924007060,  0.9879925180204854)
gl_w <- c(0.0307532419961173, 0.0703660474881081, 0.1071592204671719,
          0.1395706779261543, 0.1662692058169939, 0.1861610000155622,
          0.1984314853271116, 0.2025782419255613, 0.1984314853271116,
          0.1861610000155622, 0.1662692058169939, 0.1395706779261543,
          0.1071592204671719, 0.0703660474881081, 0.0307532419961173)
xi <- 0.5 * (gl_x + 1); w <- 0.5 * gl_w
kern <- 2 * eta * (1 - xi^eta) * xi^(eta - 1)

crown_mean <- function(f, h) sum(w * f(h * xi) * kern)

# The candidate fraction sets.
knots_at <- function(step) { k <- la[la$step == step, ]; k$height[order(k$height)] }
first_set  <- knots_at(steps[1]);  early   <- first_set / max(first_set)
mature_set <- knots_at(steps[100]); mature <- mature_set / max(mature_set)
uniform <- seq(0, 1, length.out = 58)
pooled <- unlist(lapply(steps, function(s) { k <- knots_at(s); k / max(k) }))
union_set <- sort(unique(round(pooled, 4)))
cands <- list(early = early, mature = mature, uniform = uniform, union = union_set)
# Uniform at four counts: the plan's failure signature for a bad set is an error
# that does NOT shrink with knot count, so the convergence rate is the test of
# whether placement matters beyond resolution.
for (n in c(33, 65, 129, 257))
  cands[[sprintf("uniform%d", n)]] <- seq(0, 1, length.out = n)

cat(sprintf("develop knots per step: %d to %d, mean %.1f over %d steps\n",
            min(table(la$step)), max(table(la$step)), mean(table(la$step)),
            length(steps)))
cat(sprintf("candidate sets: early %d knots, mature %d, uniform %d, union %d\n\n",
            length(early), length(mature), length(uniform), length(union_set)))

acc <- lapply(cands, function(u) list(rel = numeric(0), abs = numeric(0)))
prof <- lapply(cands, function(u) numeric(0))

for (s in steps) {
  k <- la[la$step == s, ]; k <- k[order(k$height), ]
  if (nrow(k) < 4) next
  hmax <- max(k$height)
  ref <- splinefun(k$height, k$light_availability, method = "natural")
  hs <- sp$height[sp$step == s]
  hs <- hs[hs > 0]
  if (!length(hs)) next
  ref_means <- vapply(hs, function(h) crown_mean(ref, h), numeric(1))

  for (nm in names(cands)) {
    z <- cands[[nm]] * hmax
    cand <- splinefun(z, ref(z), method = "natural")
    cm <- vapply(hs, function(h) crown_mean(cand, h), numeric(1))
    acc[[nm]]$rel <- c(acc[[nm]]$rel, abs(cm - ref_means) / ref_means)
    acc[[nm]]$abs <- c(acc[[nm]]$abs, abs(cm - ref_means))
    # and the profile error away from the crown weighting, for contrast
    zz <- seq(0, hmax, length.out = 501)
    prof[[nm]] <- c(prof[[nm]], max(abs(cand(zz) - ref(zz))))
  }
}

cat("crown-mean light: |candidate - develop| / develop, over every cohort record\n")
cat(sprintf("%10s %12s %12s %12s %14s\n", "set", "median", "p95", "max",
            "max profile"))
for (nm in names(cands))
  cat(sprintf("%10s %12.3e %12.3e %12.3e %14.3e\n", nm,
              median(acc[[nm]]$rel), quantile(acc[[nm]]$rel, 0.95),
              max(acc[[nm]]$rel), max(prof[[nm]])))
cat("\nthe last column is the worst pointwise profile error, unweighted -- it is\n")
cat("larger than the crown-mean error because the crown weight xi^(eta-1) at\n")
cat("eta = 12 puts almost no weight near the ground, where the profile bends\n")
