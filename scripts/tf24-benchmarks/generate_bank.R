# Canonical bank of hard-to-solve TF24 rainfall sequences.
#
# Each generator returns a daily rainfall vector (mm/day) for a stated horizon.
# The bank is deliberately chosen to stress DIFFERENT parts of the coupled
# soil + cohort solver: the wet end (drainage stiffness), the dry end (matric
# near-singularity + leaf-shutdown boundary crossings), long horizons (deep
# evolved meshes), abrupt storm fronts (forcing kinks), and multi-species runs
# (larger M, more threshold crossings). Sequences are saved to data/*.rds so the
# event-sizing and any future benchmark is reproducible without re-running the
# stochastic generators.
#
# Convention: rainfall(t) sampled at daily nodes t = (0:(nd-1))/365 (years).

set.seed(1)  # top-level; each generator re-seeds for reproducibility

# --- primitive: seasonal wet/dry Markov chain with gamma intensities ----------
# ann_mult: per-year multiplier on wetness (AR(1) in log gives realistic runs of
# wet/dry years). intensity_scale scales storm sizes.
markov_rain <- function(nyears, ann_mult, p01_base = 0.06, p11_base = 0.5,
                        intensity_scale = 1, shape = 0.4, seed = 1) {
  set.seed(seed)
  out <- numeric(0)
  for (y in seq_len(nyears)) {
    nd <- 365; doy <- seq_len(nd) - 1
    season <- (1 + cos(2 * pi * (doy - 15) / 365)) / 2      # 1 at mid-summer
    p01 <- pmin(0.97, p01_base * (0.1 + 0.9 * season^1.5) * ann_mult[y])
    p11 <- pmin(0.98, p11_base * (0.3 + 0.7 * season^1.5))
    wet <- logical(nd)
    for (t in 2:nd) wet[t] <- runif(1) < (if (wet[t - 1]) p11[t] else p01[t])
    scale <- (4 + 16 * season) * intensity_scale * ann_mult[y]
    rain <- numeric(nd)
    rain[wet] <- rgamma(sum(wet), shape = shape, scale = scale[wet])
    rain[rain < 0.1] <- 0
    rain <- pmin(rain, 400)   # physical daily cap (world record ~1.8 m; 400 is extreme but sane)
    out <- c(out, round(rain, 2))
  }
  out
}

ar1_log_mult <- function(nyears, rho = 0.75, sigma = 0.6, seed = 1) {
  set.seed(seed); logw <- numeric(nyears)
  for (y in 2:nyears) logw[y] <- rho * logw[y - 1] + rnorm(1, 0, sigma)
  pmin(pmax(exp(logw), 0.05), 5)   # clamp interannual multiplier to a sane range
}

# --- the bank -----------------------------------------------------------------
bank <- list()

# 1. dry_to_wet: a 25-yr aridity gradient, arid start ramping to mesic. Stresses
#    the transition through the leaf-shutdown boundary as the stand greens up.
{
  ny <- 25; ramp <- seq(0.25, 2.5, length.out = ny)
  bank$dry_to_wet <- list(
    rain = markov_rain(ny, ramp, seed = 11),
    life = ny,
    desc = "25 yr aridity gradient, arid -> mesic (boundary sweep)")
}

# 2. long_horizon: 70 yr realistic semi-arid with AR(1) interannual variability.
#    The headline target scenario; deep evolved mesh most of the run.
{
  ny <- 70; m <- ar1_log_mult(ny, seed = 22)
  bank$long_horizon <- list(
    rain = markov_rain(ny, m, intensity_scale = 1.0, seed = 22),
    life = ny,
    desc = "70 yr realistic semi-arid, AR(1) interannual (deep mesh)")
}

# 3. extended_drought: 30 yr with a hard 6-yr drought embedded (years 12-17 at
#    ~10% wetness). Stresses the dry end: matric near-singularity + mass
#    shutdown + re-wetting fronts on exit.
{
  ny <- 30; m <- rep(1.0, ny); m[12:17] <- 0.1; m[18] <- 0.3
  bank$extended_drought <- list(
    rain = markov_rain(ny, m, seed = 33),
    life = ny,
    desc = "30 yr with an embedded 6-yr severe drought (yr 12-17)")
}

# 4. intense_storms: 20 yr monsoonal - few but very intense wet-season bursts on
#    a dry baseline. Stresses forcing kinks + wet-end drainage stiffness.
{
  ny <- 20; m <- rep(1.2, ny)
  bank$intense_storms <- list(
    rain = markov_rain(ny, m, p01_base = 0.02, p11_base = 0.65,
                       intensity_scale = 3.5, shape = 0.3, seed = 44),
    life = ny,
    desc = "20 yr monsoonal: sparse, very intense bursts (kink + wet-end)")
}

# 5. multispecies: 40 yr realistic sequence; paired at run time with several
#    species (larger M, more simultaneous threshold crossings). Rainfall alone
#    here; the run config sets the assemblage.
{
  ny <- 40; m <- ar1_log_mult(ny, seed = 55)
  bank$multispecies <- list(
    rain = markov_rain(ny, m, seed = 55),
    life = ny,
    desc = "40 yr realistic; run with a multi-species assemblage (large M)")
}

# 6. whiplash: 24 yr alternating very-wet / very-dry years (drought-flood
#    whiplash). Maximal excursions across the moisture range every year.
{
  ny <- 24; m <- rep(c(2.5, 0.15), length.out = ny)
  bank$whiplash <- list(
    rain = markov_rain(ny, m, seed = 66),
    life = ny,
    desc = "24 yr drought-flood whiplash (annual full-range excursions)")
}

dir.create("scripts/tf24-benchmarks/data", showWarnings = FALSE, recursive = TRUE)
for (nm in names(bank)) {
  saveRDS(bank[[nm]], file.path("scripts/tf24-benchmarks/data", paste0(nm, ".rds")))
  cat(sprintf("%-16s %3d yr  %6d days  mean=%.2f max=%.1f  %s\n",
              nm, bank[[nm]]$life, length(bank[[nm]]$rain),
              mean(bank[[nm]]$rain), max(bank[[nm]]$rain), bank[[nm]]$desc))
}
saveRDS(names(bank), "scripts/tf24-benchmarks/data/_manifest.rds")
