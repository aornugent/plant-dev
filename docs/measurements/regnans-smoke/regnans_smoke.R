# Smoke test of the regnans workflow on TF24 with adjoints, plant#650 E1-E3:
#   1. the resident's demographic equilibrium by Newton in ln b, its slope
#      from the birth-rate column (E1, E3);
#   2. the equilibrium run's recording as the cache;
#   3. a hill climb on the invader's ln R' by its sweep (E2), trial points of
#      each line search run together in one patch against the cache;
#   4. where ln R' > 0, the invader joins at a small birth rate and the
#      two-species equilibrium is solved again by Newton, its 2 x 2 Jacobian
#      from the birth-rate columns; that run is the next cache.
# Run as: R_LIBS=<lib> Rscript regnans_smoke.R <out.rds>
suppressMessages(library(plant))
args <- commandArgs(TRUE)
log_line <- function(...) cat(sprintf(...), "\n", sep = "")
clock <- function() proc.time()[["elapsed"]]
count <- new.env()
count$runs <- 0
count$sweeps <- 0
count$invasions <- 0

lma0 <- scm_base_parameters("TF24")$strategy_default$pars[["lma"]]
stand <- function(lma, birth_rate) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- 6
  p <- add_strategies(p, trait_matrix(c(rep(0, length(lma)), rep(6, length(lma)), lma),
                                      c("TF24_floor_lambda_o", "hmat", "lma")),
                      hyperpar = TF24_hyperpar, birth_rate = as.list(birth_rate))
  full <- p$node_schedule_times[[1]]
  p$node_schedule_times <-
    rep(list(full[round(seq(1, length(full), length.out = 12))]), length(lma))
  p
}
env <- function() {
  e <- Environment("TF24")
  e$set_soil_water_state(rep(0.428 * 0.5, e$get_soil_number_of_depths()))
  e$extrinsic_drivers_set_constant("rainfall", 1)
  e
}
ctrl <- function() Control(node_density_in_birth_date = TRUE, ode_tol_rel = 1e-6,
                           ode_tol_abs = 1e-6)
run <- function(p) {
  count$runs <- count$runs + 1
  run_scm(p, env(), ctrl(), record_trajectory = TRUE)
}
sweep <- function(scm, metrics, traits) {
  count$sweeps <- count$sweeps + 1
  g <- stand_gradient(scm, metrics = metrics, traits = traits)
  stopifnot(!any(stand_gradient_refused(g)))
  g
}
invade <- function(scm, lma) {
  count$invasions <- count$invasions + 1
  scm$run_mutant(stand(lma, rep(1, length(lma))))
  scm$net_reproduction_ratios
}

# The selection gradient along TF24_hyperpar's trade-off: lma moves r_l and k_l
# too, so d ln R'/d ln lma chains the sweep's partials through the
# hyperparameterisation's Jacobian (a difference of a closed form, no runs).
traded <- c("lma", "r_l", "k_l")
trade_off <- function(lma) {
  pars <- function(l) unlist(stand(l, 1)$strategies[[1]]$pars)[traded]
  (pars(lma * (1 + 1e-6)) - pars(lma * (1 - 1e-6))) / (2e-6 * lma)
}
selection <- function(scm, lma, species = 1) {
  traits <- paste0(species, ".", traded)
  metric <- paste0(species, ".net_reproduction_ratio")
  g <- sweep(scm, metric, traits)
  R <- g$value[[metric]]
  c(log_R = log(R),
    gradient = lma * sum(g$gradient[metric, traits] * trade_off(lma)) / R)
}

# Damped Newton in ln b on F_i = ln J_i - ln b_i, dF_i/d ln b_j =
# b_j J_ij / J_i - [i == j], halving the step until max |F| falls. A species
# whose birth rate is driven below `floor` while it cannot replace itself is
# excluded, and the rest are solved again.
equilibrium <- function(lma, b, tol = 1e-8, max_it = 20, floor = 1e-3) {
  F_at <- function(lma, b) {
    n <- length(lma)
    J_names <- paste0(seq_len(n), ".offspring_production")
    b_names <- paste0(seq_len(n), ".birth_rate")
    scm <- run(stand(lma, b))
    g <- sweep(scm, J_names, b_names)
    J <- unlist(g$value[J_names])
    list(scm = scm, J = J, F = log(J) - log(b),
         D = g$gradient[J_names, b_names, drop = FALSE] * outer(1 / J, b) -
           diag(n))
  }
  at <- F_at(lma, b)
  for (k in seq_len(max_it)) {
    log_line("  newton %2d  b = %s  ln J - ln b = %s", k,
             paste(sprintf("%.6g", b), collapse = ", "),
             paste(sprintf("%+.2e", at$F), collapse = ", "))
    if (max(abs(at$F)) < tol) {
      return(list(scm = at$scm, lma = lma, b = b, J = at$J, iterations = k))
    }
    out <- b < floor & at$F < 0
    if (any(out)) {
      log_line("  excluded: species with lma %s",
               paste(sprintf("%.5g", lma[out]), collapse = ", "))
      lma <- lma[!out]
      b <- b[!out]
      at <- F_at(lma, b)
      next
    }
    # Two near-identical species leave D nearly singular: only their total
    # density is well determined. A trust region of 2 in ln b keeps the step
    # where the run is defined, and a run that fails halves it.
    step <- -solve(at$D, at$F)
    step <- step * min(1, 2 / max(abs(step)))
    for (halving in 0:10) {
      b_try <- exp(log(b) + step / 2^halving)
      try_at <- tryCatch(F_at(lma, b_try), error = function(e) NULL)
      if (!is.null(try_at) && max(abs(try_at$F)) < max(abs(at$F))) break
    }
    if (is.null(try_at)) stop("no step reduces max |F|")
    b <- b_try
    at <- try_at
  }
  stop("no equilibrium in ", max_it, " Newton steps")
}

out <- list()
t0 <- clock()

log_line("1. Resident equilibrium, lma = %.5g", lma0)
eq <- equilibrium(lma0, 10)
out$resident <- eq[c("b", "J", "iterations")]
log_line("   b* = %.6g after %d runs; R0 = %.10f", eq$b, eq$iterations,
         eq$scm$net_reproduction_ratios)

log_line("2. Cache: the equilibrium run. An invader at the resident's traits:")
cache <- eq$scm
self <- invade(cache, lma0)[[1]]
log_line("   ln R' = %+.2e (zero at the equilibrium)", log(self))
out$self_log_R <- log(self)
fd <- diff(log(invade(cache, lma0 * exp(c(-1e-5, 1e-5))))) / 2e-5
invade(cache, lma0)
sel0 <- selection(cache, lma0)
log_line("   d ln R'/d ln lma: sweep chained %.4f, central difference %.4f", sel0[["gradient"]], fd)
out$selection_check <- c(sweep = sel0[["gradient"]], difference = fd)

log_line("3. Hill climb on ln R' in ln lma along the trade-off, against the cache")
x <- log(lma0)
climb <- list()
for (it in 1:6) {
  invade(cache, exp(x))
  sel <- selection(cache, exp(x))
  # Three trial steps, run together in one patch against the cache.
  trials <- x + sign(sel[["gradient"]]) * c(0.002, 0.005, 0.01)
  R_trials <- log(invade(cache, exp(trials)))
  best <- which.max(R_trials)
  climb[[it]] <- data.frame(it = it, lma = exp(x), log_R = sel[["log_R"]],
                            gradient = sel[["gradient"]],
                            next_lma = exp(trials[best]), next_log_R = R_trials[best])
  log_line("   %d  lma = %.5g  ln R' = %+.4f  d ln R'/d ln lma = %+.3f  -> lma %.5g, ln R' %+.4f",
           it, exp(x), sel[["log_R"]], sel[["gradient"]], exp(trials[best]), R_trials[best])
  if (R_trials[best] <= sel[["log_R"]]) break
  x <- trials[best]
  if (R_trials[best] > 0.1) break
}
out$climb <- do.call(rbind, climb)
lma1 <- exp(x)
R1 <- invade(cache, lma1)
log_line("   invader lma = %.5g with ln R' = %+.4f", lma1, log(R1))

if (log(R1) > 0) {
  log_line("4. Invasion: the invader at its own equilibrium, then the old resident as its invader")
  eq_inv <- equilibrium(lma1, eq$b)
  back <- log(invade(eq_inv$scm, lma0))
  log_line("   invader alone: b* = %.6g after %d runs; the old resident's ln R' = %+.4f",
           eq_inv$b, eq_inv$iterations, back)
  out$invader_alone <- eq_inv[c("b", "J", "iterations")]
  out$old_resident_log_R <- back
  if (back < 0) {
    log_line("   the old resident cannot return: the invader replaces it")
    eq2 <- eq_inv
  } else {
    log_line("   mutual invasion: the two coexist; their joint equilibrium")
    eq2 <- equilibrium(c(lma0, lma1), c(eq$b, eq_inv$b))
  }
  out$community <- eq2[c("lma", "b", "J", "iterations")]
  # J / b, not the SCM's ratios: run_mutant() made the old resident its community.
  log_line("   community lma = %s  b* = %s  J/b = %s",
           paste(sprintf("%.5g", eq2$lma), collapse = ", "),
           paste(sprintf("%.6g", eq2$b), collapse = ", "),
           paste(sprintf("%.10f", eq2$J / eq2$b), collapse = ", "))

  log_line("5. The next cache: each survivor's selection gradient as an invader of it")
  cache2 <- eq2$scm
  sel2 <- sapply(eq2$lma, function(l) {
    invade(cache2, l)
    selection(cache2, l)
  })
  colnames(sel2) <- sprintf("lma %.5g", eq2$lma)
  print(sel2)
  out$selection_next <- sel2
}

out$cost <- c(runs = count$runs, sweeps = count$sweeps,
              invasions = count$invasions, seconds = clock() - t0)
log_line("Cost: %d recorded runs, %d sweeps, %d invasions, %.1f s",
         count$runs, count$sweeps, count$invasions, clock() - t0)
if (length(args)) saveRDS(out, args[[1]])
