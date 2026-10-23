# The closed-canopy TF24 stand of spikes/field-dimension-066 (CASE closed) and
# the open long-drought stand (CASE open), as spikes/leaf-table/run.R builds
# them, with helpers to run many invaders against one resident in one process.
#
# Invader variants are told apart by a relative offset on vcmax_25 of k*1e-12;
# the probe build (probe.patch) scales one variant's solved P by the matching
# entry of PLANT_LEAF_PSCALES. The keys are read at the first leaf call, so
# call set_scales() before run_resident().
HERE <- "/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even"
Sys.setenv(PLANT_LIB = Sys.getenv("PLANT_LIB",
  "/home/a/.claude/jobs/9d586e52/tmp/breakeven/rlib"))
Sys.setenv(LIFETIME = Sys.getenv("LIFETIME", "40"))
source(file.path(HERE, "..", "..", "harness", "long_drought.R"))
OUTDIR <- "/home/a/.claude/jobs/9d586e52/tmp/breakeven"

CASE <- Sys.getenv("CASE", "closed")
REGIME <- if (CASE == "open") "long-drought" else "long-wet"
LMA_SHIFT <- if (CASE == "open") 0 else -1
LNB <- as.numeric(Sys.getenv("LNB", if (CASE == "open") "1.539" else "3.595"))
TOL <- as.numeric(Sys.getenv("TOL", "1e-4"))
NINTRO <- as.integer(Sys.getenv("NINTRO", "108"))
TIMES <- uniform_times(NINTRO)
# EXTRA=n: n more introductions between 0 and the second uniform one, spaced
# geometrically from 1e-3 of that interval, to resolve the first cohorts.
NEXTRA <- as.integer(Sys.getenv("EXTRA", "0"))
if (NEXTRA > 0) {
  TIMES <- sort(c(TIMES, TIMES[2] * 10^seq(-3, log10(0.7), length.out = NEXTRA)))
}
NINTRO <- length(TIMES)
# Invaders on every EVERY-th introduction (3 in the pilot; 1 = all of them).
EVERY <- as.integer(Sys.getenv("EVERY", "3"))
TIMES_INV <- TIMES[seq(1, NINTRO, EVERY)]
TRAITS <- c("lma", "rho", "hmat", "K_s", "rooting_depth_max", "vcmax_25")
TRAIT0 <- local({
  d <- scm_base_parameters("TF24")$strategy_default$pars
  v <- vapply(TRAITS, function(n) d[[n]], 0)
  v[["lma"]] <- LMA0 * exp(LMA_SHIFT)
  v
})
pool <- local({
  set.seed(20261023)
  n <- 47
  x <- sapply(TRAITS, function(.) (sample(n) - runif(n)) / n * 0.8 - 0.4)
  rbind(0, x)
})

ctrl <- control()
ctrl$ode_tol_rel <- TOL
ctrl$ode_tol_abs <- TOL * 1e-4
ctrl$node_density_in_birth_date <- TRUE

resident_parameters <- function() {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(TRAIT0, TRAITS), birth_rate = exp(LNB))
  p$node_schedule_times <- list(TIMES)
  p
}

# Trait matrix for pool rows `rows`, each with its own vcmax_25 key.
variant_traits <- function(rows) {
  m <- t(apply(pool[rows, , drop = FALSE], 1, function(x) TRAIT0 * exp(x)))
  colnames(m) <- TRAITS
  m[, "vcmax_25"] <- m[, "vcmax_25"] * (1 + seq_len(nrow(m)) * 1e-12)
  m
}

set_scales <- function(m, scale) {
  Sys.setenv(PLANT_LEAF_KEYS = paste(sprintf("%.17g", m[, "vcmax_25"]), collapse = ","),
             PLANT_LEAF_PSCALES = paste(sprintf("%.17g", scale), collapse = ","))
}

run_resident <- function(p = resident_parameters()) {
  scm <- run_scm(p, mkenv(REGIME), ctrl, run = FALSE)
  scm$collect <- FALSE
  scm$run()
  scm
}

node_state <- function(n) {
  x <- n$individual$ode_state
  names(x) <- n$individual$ode_names
  x
}

# One run_mutant over the invaders in m; per invader, ln R' and per cohort its
# birth date, quadrature weight, lifetime output and end states.
invade <- function(scm, m, keep_states = FALSE, times = TIMES_INV) {
  q <- add_mutant(scm$parameters, m, birth_rate = rep(1, nrow(m)))
  q$node_schedule_times <- rep(list(times), nrow(m))
  scm$keep_states <- keep_states
  scm$run_mutant(q)
  lnR <- log(scm$net_reproduction_ratios)
  cohorts <- lapply(seq_len(nrow(m)), function(i) {
    sp <- scm$patch$species[[i]]
    nd <- sp$nodes
    w <- sp$establishment_weights[seq_along(nd)]
    st <- do.call(rbind, lapply(nd, node_state))
    pd <- sp$patch_densities
    pd <- if (length(pd) >= length(nd)) pd[seq_along(nd)] else NA
    data.frame(t = sp$node_times[seq_along(nd)], w = w, pd = pd,
               R_c = sp$net_reproduction_ratio_by_node, st, check.names = FALSE)
  })
  list(lnR = lnR, cohorts = cohorts)
}
