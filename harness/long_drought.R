# The lifetime-40 long-drought TF24 stand the performance notes and
# aornugent/plant#92 and #93 measure on:
# - one species at lma = 0.32;
# - 41 years of generated daily rainfall with three multi-year droughts;
# - the birth-date coordinate;
# - ode_tol = 1e-3;
# - a zero-depth rainfall pulse at each of the record's 2931 active knots, so
#   that every step lies inside one cubic span of the forcing.
#
# Load plant one of two ways:
#   PLANT_LIB=/path/to/lib  an installed plant, e.g. develop built against
#                           odelia 0.4.0 and phylloptim 0.8.1 in a private
#                           library (see docs/handover.md);
#   PLANT_DIR=/path/to/src  a source tree, through pkgload::load_all (the
#                           default is the plant submodule).
# odelia is always loaded with library(), never load_all() (AGENTS.md).
Sys.setenv(TESTTHAT_PARALLEL = "false")
local({
  lib <- Sys.getenv("PLANT_LIB")
  if (nzchar(lib)) {
    .libPaths(c(lib, .libPaths()))
    suppressMessages(library(odelia, lib.loc = lib))
    suppressMessages(library(plant, lib.loc = lib))
  } else {
    suppressMessages(library(odelia))
    here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) ".")
    dir <- Sys.getenv("PLANT_DIR", file.path(here, "..", "plant"))
    suppressMessages(pkgload::load_all(dir, quiet = TRUE))
  }
})

LIFETIME <- 40
LMA0 <- 0.32
JTOL <- 1e-3
SCEN <- "long-drought"

# The record: occurrence is a seasonal two-state Markov chain; a wet day's
# depth is gamma; each year's depths are scaled by that year's multiplier, so
# the record carries droughts and wet years. Deterministic from its seeds.
gen_rain_mix <- function(seed, ndays, p01b, p11b, shape, scale0, scaleb,
                         year_mult = 1, amp = 1) {
  set.seed(seed)
  doy <- (seq_len(ndays) - 1) %% 365
  s <- (1 + cos(2 * pi * (doy - 15) / 365)) / 2
  s <- 0.5 + amp * (s - 0.5)
  p01 <- pmin(0.95, 0.010 + p01b * s^1.5)
  p11 <- pmin(0.98, 0.150 + p11b * s^1.5)
  wet <- logical(ndays)
  for (t in 2:ndays) wet[t] <- runif(1) < (if (wet[t - 1]) p11[t] else p01[t])
  sc <- scale0 + scaleb * s
  r <- numeric(ndays)
  r[wet] <- rgamma(sum(wet), shape = shape, scale = sc[wet])
  yr <- 1 + (seq_len(ndays) - 1) %/% 365
  r <- r * rep(year_mult, length.out = max(yr))[yr]
  r[r < 0.1] <- 0
  round(r, 2)
}

RAIN_YEARS <- 41L
RAIN_DAYS <- RAIN_YEARS * 365L

# Ordinary years around 1, three multi-year droughts (years 8-10, 19-22,
# 32-34) and four wet years.
MULT_LONG <- local({
  set.seed(7)
  m <- round(runif(RAIN_YEARS, 0.85, 1.30), 2)
  m[8:10] <- c(0.45, 0.30, 0.40)
  m[19:22] <- c(0.50, 0.28, 0.35, 0.55)
  m[32:34] <- c(0.38, 0.32, 0.50)
  m[c(5, 14, 25, 38)] <- c(1.55, 1.60, 1.50, 1.65)
  m
})

RAIN_SPECS <- list(
  "long-drought" = list(p01b = 0.14, p11b = 0.45, shape = 0.9, scale0 = 3,
                        scaleb = 9, year_mult = MULT_LONG, amp = 0.8,
                        seed = 31, mean = 3.0),
  # The same occurrence pattern at a wetter mean and without the droughts.
  "long-wet" = list(p01b = 0.14, p11b = 0.45, shape = 0.9, scale0 = 3,
                    scaleb = 9, year_mult = rep(1, RAIN_YEARS), amp = 0.8,
                    seed = 31, mean = 5.0))

rain_record <- function(name) {
  k <- RAIN_SPECS[[name]]
  r <- gen_rain_mix(k$seed, RAIN_DAYS, k$p01b, k$p11b, k$shape, k$scale0,
                    k$scaleb, k$year_mult, k$amp)
  round(r * k$mean / mean(r), 2)
}

mkenv <- function(scen = SCEN) {
  e <- Environment("TF24")
  days <- seq(0, RAIN_DAYS)
  e$extrinsic_drivers_set_variable("rainfall", days / 365,
                                   rep(rain_record(scen), length.out = length(days)))
  e
}

# Where the rainfall interpolant's second derivative jumps: at every knot
# except one where the series is zero on both sides, because the
# interpolant is flat across a zero pair.
active_knots <- function(scen = SCEN) {
  days <- seq(0, RAIN_DAYS)
  x <- days / 365
  y <- rep(rain_record(scen), length.out = length(days))
  n <- length(y); nz <- y != 0
  a <- x[nz | c(FALSE, nz[-n]) | c(nz[-1], FALSE)]
  a[a > 0 & a < LIFETIME]
}
AK <- active_knots()

pulse_rows <- function(times) {
  if (length(times) == 0) return(NULL)
  rainfall_pulse(time = times, depth = rep(0, length(times)))
}

# The nested uniform ladder over [0, 39.63]: each level bisects the one below
# it, and 108 nodes are spaced 40/108 apart.
uniform_times <- function(n) seq(0, 107 * 40 / 108, length.out = n)

# One run. `stops` are extra times the integrator lands on, entered as
# zero-depth pulses beside the introductions; to hold the time grid across a
# ladder, give every rung the finest rung's introduction times as stops too.
run_J <- function(times, lma = LMA0, tol = JTOL, stops = AK, scen = SCEN) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(lma, "lma"))
  p$node_schedule_times <- list(times)
  ct <- control()
  ct$ode_tol_rel <- tol
  ct$ode_tol_abs <- tol
  ct$node_density_in_birth_date <- TRUE
  ev <- if (length(stops) == 0) NULL else
    events(events_default(p), pulse_rows(sort(unique(stops))))
  t0 <- proc.time()[["elapsed"]]
  scm <- tryCatch(run_scm(p, mkenv(scen), ct, events = ev),
                  error = function(e) conditionMessage(e))
  secs <- proc.time()[["elapsed"]] - t0
  if (is.character(scm)) return(list(ok = FALSE, err = scm, secs = secs))
  list(ok = TRUE, J = sum(scm$offspring_production),
       steps = length(scm$ode_times), nodes = length(times), secs = secs,
       b = scm$patch$species[[1]]$node_times)
}
