# The stand at its demographic equilibrium, J(b*) = b*, on one rainfall record,
# and what an evolutionary analysis pays there: the equilibrium by a secant in
# ln b and by iterating b <- J(b), the stand's run and sweep at b*, invaders
# walked on that run with one's sweep, and a move in lma warm-started by the
# implicit function theorem.
#
#   PLANT_LIB=... [REGIME=long-drought] [TOL=1e-4] [ATOL=1e-4] [NODES=108] \
#     [SPLIT=1] [FIXED_MAX=8] [BATCH_SWEEP=1] OUT=eq.rds Rscript harness/equilibrium.R
#
# The introductions are held at NODES uniform times and the steps adapt at TOL.
# Invaders walk at a birth rate of 1, so each one's J' is its net reproduction
# ratio. FIXED_MAX caps the iterations of b <- J(b), the two the secant shares
# included. BATCH_SWEEP=1 also sweeps the five-invader walk.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
regime <- Sys.getenv("REGIME", SCEN)
tol <- as.numeric(Sys.getenv("TOL", "1e-4"))
atol <- as.numeric(Sys.getenv("ATOL", "1e-4"))
nodes <- as.integer(Sys.getenv("NODES", "108"))
fixed_max <- as.integer(Sys.getenv("FIXED_MAX", "8"))
out_file <- Sys.getenv("OUT")
times <- uniform_times(nodes)

ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE
if (Sys.getenv("SPLIT") == "1") ct$ode_split_sign_changes <- TRUE

# The stand at lma = LMA0 (1 + lma_rel), moved after the hyperparameterisation
# has derived the rest, at birth rate b.
stand <- function(b, lma_rel = 0) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"))
  p$strategies[[1]]$pars$lma <- LMA0 * (1 + lma_rel)
  p$strategies[[1]]$birth_rate_y <- b
  p$node_schedule_times <- list(times)
  p
}
# Invaders at lma = LMA0 * factor through the hyperparameterisation, each at
# birth rate 1, on the stand's introductions.
invaders <- function(factor) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0 * factor, "lma"),
                      birth_rate = rep(1, length(factor)))
  p$node_schedule_times <- rep(list(times), length(factor))
  p
}
ev <- events(events_default(stand(1)), pulse_rows(sort(unique(active_knots(regime)))))
env <- mkenv(regime)

clock <- function() proc.time()[["elapsed"]]
out <- list(setting = list(regime = regime, tol = tol, tol_abs = ct$ode_tol_abs,
                           nodes = nodes, lma = LMA0, lifetime = LIFETIME,
                           split = isTRUE(ct$ode_split_sign_changes)),
            versions = list(plant = as.character(packageVersion("plant")),
                            odelia = as.character(packageVersion("odelia")),
                            lib = Sys.getenv("PLANT_LIB")),
            started = format(Sys.time(), tz = "UTC", usetz = TRUE),
            runs = list(), phases = list(), failures = list())
save <- function() if (nzchar(out_file)) saveRDS(out, out_file)
phase <- function(name, f) {
  t0 <- clock()
  v <- tryCatch(f(), error = function(e) {
    out$failures[[name]] <<- conditionMessage(e)
    NULL
  })
  out$phases[[name]] <<- list(secs = clock() - t0, ok = !is.null(v))
  save()
  v
}

# One forward run at birth rate b, kept as a row of out$runs under `role`.
forward <- function(b, role, lma_rel = 0, record = FALSE) {
  t0 <- clock()
  scm <- run_scm(stand(b, lma_rel), env, ct, events = ev, record_trajectory = record)
  J <- sum(scm$offspring_production)
  row <- list(role = role, b = b, lma_rel = lma_rel, J = J, f = log(J) - log(b),
              secs = clock() - t0, steps = length(scm$ode_times),
              splits = if (!is.null(scm$ode_splits)) sum(scm$ode_splits) else NA)
  out$runs[[length(out$runs) + 1L]] <<- row
  save()
  cat(sprintf("%-8s b %.10g  J %.10g  ln J - ln b %+.3e  %.0f s  %d steps  %s splits\n",
              role, b, J, row$f, row$secs, row$steps, format(row$splits)))
  if (record) scm else row
}

# The equilibrium by a secant on f(x) = ln J(e^x) - x, x = ln b, from b = 1 and
# the fixed point's first step; each move is held to a factor of e^3.
secant <- phase("secant", function() {
  r0 <- forward(1, "secant")
  x <- c(0, log(r0$J))
  f <- r0$f
  r <- forward(exp(x[2]), "secant")
  f <- c(f, r$f)
  while (abs(f[length(f)]) >= 1e-5 && length(f) < 14) {
    n <- length(f)
    step <- -f[n] * (x[n] - x[n - 1]) / (f[n] - f[n - 1])
    x <- c(x, x[n] + max(-3, min(3, step)))
    f <- c(f, forward(exp(x[n + 1]), "secant")$f)
  }
  n <- length(f)
  list(x = x, f = f, b_star = exp(x[n]),
       slope = (f[n] - f[n - 1]) / (x[n] - x[n - 1]))
})
if (is.null(secant)) quit(status = 1)
b_star <- secant$b_star
# d ln J / d ln b at b*, the fixed point's multiplier there.
out$equilibrium <- list(b_star = b_star, f_slope = secant$slope,
                        multiplier = 1 + secant$slope, runs = length(secant$f))
save()

# b <- J(b) from b = 1; its first two runs are the secant's.
phase("fixed_point", function() {
  b <- exp(secant$x[2])
  J <- exp(secant$x[2] + secant$f[2])
  for (i in seq_len(max(0, fixed_max - 2))) {
    b <- J
    J <- forward(b, "fixed")$J
  }
  TRUE
})

scm <- phase("stand_at_b_star", function() forward(b_star, "b_star", record = TRUE))
if (!is.null(scm)) {
  out$stand <- list(J = sum(scm$offspring_production), times = scm$ode_times,
                    splits = scm$ode_splits)
  g <- phase("stand_sweep", function() stand_gradient(scm, metrics = "offspring_production"))
  if (!is.null(g)) {
    grad <- g$gradient["offspring_production", ]
    pars <- stand(b_star)$strategies[[1]]$pars
    theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
    out$stand$elasticity <- ifelse(theta == 0, 1, theta) * grad / out$stand$J
    out$stand$refusal <- g$refusal[["offspring_production"]]
  }
  save()
  # The invader at the stand's own traits, then its sweep: the selection gradient.
  if (isTRUE(phase("walk_1", function() { scm$run_mutant(invaders(1)); TRUE }))) {
    out$invader <- list(J = sum(scm$offspring_production))
    gi <- phase("invader_sweep", function() stand_gradient(scm, metrics = "offspring_production"))
    if (!is.null(gi)) {
      grad <- gi$gradient["offspring_production", ]
      pars <- invaders(1)$strategies[[1]]$pars
      theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
      out$invader$elasticity <- ifelse(theta == 0, 1, theta) * grad / out$invader$J
    }
    save()
  }
  factors <- exp(c(-0.1, -0.05, 0, 0.05, 0.1))
  if (isTRUE(phase("walk_5", function() { scm$run_mutant(invaders(factors)); TRUE }))) {
    out$invaders5 <- list(factor = factors, J = scm$offspring_production)
    save()
    if (Sys.getenv("BATCH_SWEEP") == "1") {
      g5 <- phase("walk_5_sweep", function() stand_gradient(scm, metrics = "offspring_production"))
      if (!is.null(g5)) out$invaders5$gradient <- g5$gradient["offspring_production", ]
      save()
    }
  }
}

# lma moved by 1e-2 alone: the stand at b*, then at b* moved by the implicit
# function theorem's d ln b* / d ln lma = -(d ln J / d ln lma) / (d ln J / d ln b - 1).
e_lma <- out$stand$elasticity[["1.lma"]]
if (!is.null(e_lma)) {
  s <- -e_lma / secant$slope
  out$ift <- list(d_ln_b_d_ln_lma = s)
  phase("ift", function() {
    a <- forward(b_star, "ift_held", lma_rel = 0.01)
    w <- forward(b_star * exp(log(1.01) * s), "ift_moved", lma_rel = 0.01)
    out$ift$f_held <<- a$f
    out$ift$f_moved <<- w$f
    TRUE
  })
}
out$finished <- format(Sys.time(), tz = "UTC", usetz = TRUE)
save()
