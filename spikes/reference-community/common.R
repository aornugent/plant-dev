# Shared setup for the TF24 reference community: the closed-canopy stand of
# spikes/field-dimension-066 (long-wet record, lifetime 40, 108 uniform
# introductions held in every run, birth-date coordinate, ode_tol 1e-4), one
# recording per call, and the invader in a recorded field.
#
# Traits evolve on a log scale. Every gradient is per unit ln(trait), taken
# through TF24_hyperpar (the trait's total derivative along its trade-off).
# F_i = ln R_i; F_lnb[i, j] = dF_i/d ln b_j.
W <- "/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42"
Sys.setenv(PLANT_LIB = Sys.getenv("PLANT_LIB", "/home/a/.claude/jobs/9d586e52/tmp/refcomm/rlib"))
Sys.setenv(LIFETIME = "40")
source(file.path(W, "harness", "long_drought.R"))
suppressMessages(library(parallel))

HERE <- file.path(W, "spikes", "reference-community")
TMP <- "/home/a/.claude/jobs/9d586e52/tmp/refcomm"
REGIME <- Sys.getenv("REGIME", "long-wet")
TOL <- as.numeric(Sys.getenv("TOL", "1e-4"))
NODES <- as.integer(Sys.getenv("NODES", "108"))
# EARLY extra introductions halve the first interval EARLY times over: the
# cohort born into the bare patch tops the canopy, and lumping its first
# interval into one crown puts a step in invader fitness at theta' = theta.
# EARLY_RATIO is the geometric ratio between successive early introductions.
EARLY <- as.integer(Sys.getenv("EARLY", "0"))
EARLY_RATIO <- as.numeric(Sys.getenv("EARLY_RATIO", "2"))
TIMES <- local({
  t <- seq(0, LIFETIME * (NODES - 1) / NODES, length.out = NODES)
  sort(c(t, t[2] * EARLY_RATIO^-seq_len(EARLY)))
})
EVOLVE <- strsplit(Sys.getenv("EVOLVE", "lma,rho,vcmax_25"), ",")[[1]]
METRIC <- function(i) paste0(i, ".net_reproduction_ratio")

# Every trait the stand sets: lma 0.32 e^-1 and the rest at TF24's defaults.
BASE_TRAITS <- c("lma", "rho", "hmat", "K_s", "rooting_depth_max", "vcmax_25")
THETA_BASE <- local({
  d <- scm_base_parameters("TF24")$strategy_default$pars
  v <- vapply(BASE_TRAITS, function(n) d[[n]], 0)
  v[["lma"]] <- LMA0 * exp(as.numeric(Sys.getenv("LMA_SHIFT", "-1")))
  v
})

# x: an m x length(EVOLVE) matrix of ln-trait shifts from THETA_BASE.
traits_at <- function(x) {
  x <- rbind(x)
  m <- matrix(THETA_BASE, nrow(x), length(THETA_BASE), byrow = TRUE,
              dimnames = list(NULL, BASE_TRAITS))
  m[, EVOLVE] <- m[, EVOLVE] * exp(x)
  m
}

ctrl <- function(tol = TOL) {
  ct <- control()
  ct$ode_tol_rel <- tol
  ct$ode_tol_abs <- tol * 1e-4
  ct$node_density_in_birth_date <- TRUE
  ct
}

stand <- function(lnb, x) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, traits_at(x), birth_rate = exp(lnb))
  p$node_schedule_times <- rep(list(TIMES), length(lnb))
  p
}

# The total derivative of each swept row along the trade-off, per unit
# ln(trait) of species i's EVOLVE traits, and per unit ln b. `G` is one partial
# row named by the backend's trait names.
chain_row <- function(G, scm, i, lnb = NULL) {
  hp <- param_hyperpar(scm$parameters)
  s <- scm$parameters$strategies[[i]]
  J <- plant:::trade_off(s, i, hp)
  cols <- paste0(i, ".", EVOLVE)
  tot <- G[cols]
  from <- intersect(rownames(J), names(G))
  along <- intersect(colnames(J), cols)
  tot[along] <- tot[along] + drop(G[from] %*% J[from, along, drop = FALSE])
  th <- unlist(s$pars[EVOLVE])
  out <- setNames(tot * th, EVOLVE)
  if (!is.null(lnb)) {
    br <- paste0(seq_along(lnb), ".birth_rate")
    out <- c(out, setNames(G[br] * exp(lnb), paste0("lnb", seq_along(lnb))))
  }
  out
}

sweep_rows <- function(scm, rows, fixed) {
  b <- plant:::census_backend(scm)
  plant:::fix_field_in_last_sweep(fixed)
  on.exit(plant:::fix_field_in_last_sweep(FALSE))
  s <- b$trait_gradient(scm, rows)
  bad <- !vapply(s$refusal, is.null, TRUE)
  if (any(bad)) stop("refused: ", paste(rows[bad], collapse = ", "))
  lapply(s$gradient, setNames, b$trait_names(scm))
}

# One recording at (lnb, x): F, F_lnb (m x m), F_theta (m x m*k, kept) and g
# (m x k, cut), all per unit ln. Saved under `file` if given.
record <- function(lnb, x, file = NULL, scm_out = FALSE) {
  if (!is.null(file) && file.exists(file) && !scm_out) return(readRDS(file))
  x <- rbind(x)
  m <- length(lnb)
  t0 <- proc.time()[[3]]
  p <- stand(lnb, x)
  scm <- run_scm(p, mkenv(REGIME), ctrl(), run = FALSE)
  scm$keep_states <- TRUE
  scm$run()
  t1 <- proc.time()[[3]]
  R <- scm$net_reproduction_ratios
  k <- length(EVOLVE)
  F_lnb <- matrix(0, m, m)
  F_th <- matrix(0, m, m * k)
  g <- matrix(0, m, k, dimnames = list(NULL, EVOLVE))
  for (i in seq_len(m)) {
    # Kept rows for every species ride with species 1's cut; each later
    # species' cut is a sweep of its own (the cut truncates the tape).
    rows <- if (i == 1) c(METRIC(seq_len(m)), METRIC(1)) else METRIC(i)
    sw <- sweep_rows(scm, rows, TRUE)
    if (i == 1) for (j in seq_len(m)) {
      full <- unlist(lapply(seq_len(m), function(sp)
        chain_row(sw[[j]], scm, sp)))
      F_th[j, ] <- full / R[j]
      F_lnb[j, ] <- sw[[j]][paste0(seq_len(m), ".birth_rate")] * exp(lnb) / R[j]
    }
    g[i, ] <- chain_row(sw[[length(sw)]], scm, i) / R[i]
  }
  t2 <- proc.time()[[3]]
  out <- list(lnb = lnb, x = x, F = log(R), F_lnb = F_lnb, F_theta = F_th, g = g,
              steps = length(scm$ode_times), secs_run = t1 - t0,
              secs_sweep = t2 - t1)
  if (!is.null(file)) saveRDS(out, file)
  if (scm_out) out$scm <- scm
  out
}

# Invaders at ln-trait shifts `xi` (rows) in the field `scm` recorded, on the
# full schedule: ln R' and, if `grad`, the held-field gradient per unit ln
# trait. Destroys scm's resident state (run_mutant replaces it); the recorded
# field persists for further calls.
invade <- function(scm, xi, grad = TRUE) {
  xi <- rbind(xi)
  n <- nrow(xi)
  t0 <- proc.time()[[3]]
  q <- add_mutant(scm$parameters, traits_at(xi), birth_rate = rep(1, n))
  q$node_schedule_times <- rep(list(TIMES), n)
  scm$run_mutant(q)
  lnR <- log(scm$net_reproduction_ratios)
  t1 <- proc.time()[[3]]
  g <- NULL
  if (grad) {
    sw <- sweep_rows(scm, METRIC(seq_len(n)), FALSE)
    g <- t(vapply(seq_len(n), function(i)
      chain_row(sw[[i]], scm, i) / exp(lnR[i]), numeric(length(EVOLVE))))
    colnames(g) <- EVOLVE
  }
  list(xi = xi, lnR = lnR, g = g, secs_run = t1 - t0,
       secs_sweep = proc.time()[[3]] - t1)
}
