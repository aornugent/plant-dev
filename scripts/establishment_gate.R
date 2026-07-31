#   Rscript scripts/establishment_gate.R
#
# The establishment gate's argument, on both sides.
#
# TF24's establishment_probability closes on `if (net_mass_production_dt_ > 0)`,
# un-smoothed, and that zero derivative sits on every census metric's gradient
# through the recruitment channel. Deciding whether to mollify it needs the scale of
# the argument it tests, and a closed-side census alone cannot supply that: it says
# how negative the failures are and nothing about what a success looks like. This
# measures both arms, so the threshold can be judged against the distribution it
# sits inside rather than against a median taken over every cohort in the stand.
#
# Needs ../docs/reports/establishment-gate.patch applied to the tree it loads, which
# counts and bins the argument behind PLANT_NMP_PROBE and writes to stderr. The
# instrumentation is not committed to the model.
#
# CONFIGURATION. plant p0/phase-0 at e171efb2 (the forward-model prerequisites merged
# off develop 141dc8df), odelia 0.1.0 installed, built -O2 -DNDEBUG -g0 through
# pkgbuild::compile_dll(debug = FALSE) after rm -f src/*.o src/*.so. TF24 / TF24_Env,
# one strategy at lma 0.1978791, Control(), refine_schedule = FALSE,
# max_patch_lifetime = 105.32 set on the base parameters before add_strategies, five
# soil layers, default driver. The denominator is 35 133 stage evaluations of the
# boundary node -- once per species per Runge-Kutta stage, 249 per introduction --
# and not the 141 introductions.
#
# RESULTS. The instrumented run reproduces the uninstrumented value exactly,
# offspring 42.180107697778624 at 5092 accepted steps, so the counters cost nothing.
#
#   closed arm   8112 of 35133 (23.1%)   -3.344298e-05 .. -7.886865e-09
#   open arm    27021           p01 2.539e-06  p10 8.219e-06  median 1.611e-05
#                               p90 4.571e-05  max 3.112e-04
#
# The closed arm's most negative value is about twice the open arm's median, so the
# two arms are on one scale and the sign test separates real carbon states. It
# follows that storage_prod_eps = 1e-4, the scale develop applies to the positive
# part of the same quantity one function away, is six times the open arm's median and
# would smear the whole distribution; a scale sized against this argument would be
# about 1e-6. Recorded in ../docs/tf24-correctness.md as the reason the hard gate
# stays.
#
# The closed arm is confined to t in [3.22, 8.54], the recruitment window, and is
# absent from every later decile -- so a re-run finite difference of a census
# gradient crosses the gate there and nowhere else.

suppressMessages({ library(odelia); pkgload::load_all(commandArgs(TRUE)[1], quiet = TRUE) })

p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 105.32
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
scm <- run_scm(p, Environment("TF24"), Control(), collect = FALSE, refine_schedule = FALSE)
cat(sprintf("offspring %.17g  steps %d\n",
            sum(scm$offspring_production), length(scm$ode_times)))
