# d, the effective dimension of TF24's competitive field, on the odelia 0.9.0
# stack: one TF24 resident near demographic equilibrium on a rainfall record.
# Each run moves one resident input (ln b or a trait, by +-DELTA), records the
# resident's run, and replays a pool of invaders in that recorded field
# (scm$run_mutant), so every invader takes the resident's steps and reads the
# field it made:
#   making:  light by height and patch age, soil water by depth and patch age,
#            read off the collected snapshots at the introduction times;
#   sensing: each invader's ln R' in that field.
# Every run holds one node schedule (108 uniform introductions; invaders on
# every third). A step spanning a knot of the rain substeps the soil (plant
# 33a5bddf), which a zero-depth pulse per knot reproduces to 1e-5 in ln R' at
# twice the cost, so the knots are not pulsed.
#
#   STAGE=eq    REGIME=long-drought LNB0=1.54 Rscript field_dimension.R
#   STAGE=runs  REGIME=long-drought Rscript field_dimension.R
#   STAGE=fit   REGIME=long-drought Rscript field_dimension.R
#
# CASE names a variant of the stand (a record and resident traits, below); the
# default is the record alone. Each run is saved on its own under RUN_DIR.
Sys.setenv(PLANT_LIB = "/home/a/.claude/jobs/9d586e52/rlib-d066")
Sys.setenv(LIFETIME = "40")
source("/home/a/dev/plant-dev/.claude/worktrees/agent-aff6cbd1ac6c0084f/harness/long_drought.R")
suppressMessages(library(parallel))

HERE <- "/home/a/dev/plant-dev/.claude/worktrees/agent-aff6cbd1ac6c0084f/spikes/field-dimension-066"
REGIME <- Sys.getenv("REGIME", "long-drought")
CASE <- Sys.getenv("CASE", REGIME)
STAGE <- Sys.getenv("STAGE", "runs")
WORKERS <- as.integer(Sys.getenv("WORKERS", "4"))
RUN_DIR <- file.path("/home/a/.claude/jobs/9d586e52/tmp/d066/runs", CASE)
dir.create(RUN_DIR, recursive = TRUE, showWarnings = FALSE)

TOL <- 1e-4
DELTA <- 0.2
TIMES <- uniform_times(108)
# Invaders enter at every INV_EVERY-th introduction; INV_N keeps the pool's
# first INV_N members (the draw is the same).
TIMES_INV <- TIMES[seq(1, 108, as.integer(Sys.getenv("INV_EVERY", "3")))]
INV_N <- as.integer(Sys.getenv("INV_N", "0"))

ctrl <- function(tol = TOL) {
  ct <- control()
  ct$ode_tol_rel <- tol
  ct$ode_tol_abs <- tol * 1e-4
  ct$node_density_in_birth_date <- TRUE
  ct
}

TRAITS <- c("lma", "rho", "hmat", "K_s", "rooting_depth_max", "vcmax_25")
# Resident traits, as ln-multiples of the stand's (lma 0.32, the rest TF24's
# defaults): RES_SHIFT="lma=-0.5,vcmax_25=0.3".
TRAIT0 <- local({
  d <- scm_base_parameters("TF24")$strategy_default$pars
  v <- vapply(TRAITS, function(n) d[[n]], 0)
  v[["lma"]] <- LMA0
  s <- Sys.getenv("RES_SHIFT")
  if (nzchar(s)) for (kv in strsplit(strsplit(s, ",")[[1]], "=")) {
    v[[kv[1]]] <- v[[kv[1]]] * exp(as.numeric(kv[2]))
  }
  v
})

# The pool: the resident first (the identity check), then a Latin hypercube in
# ln-trait over +-0.4 in all six traits.
N_POOL <- as.integer(Sys.getenv("N_POOL", "48"))
pool <- local({
  set.seed(20261023)
  n <- N_POOL - 1
  x <- sapply(TRAITS, function(.) (sample(n) - runif(n)) / n * 0.8 - 0.4)
  rbind(0, x)
})

stand <- function(lnb, dtrait = setNames(rep(0, length(TRAITS)), TRAITS)) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(TRAIT0 * exp(dtrait), TRAITS),
                      birth_rate = exp(lnb))
  p$node_schedule_times <- list(TIMES)
  p
}
invaders <- function(p) {
  x <- if (INV_N > 0) pool[seq_len(INV_N), , drop = FALSE] else pool
  m <- t(apply(x, 1, function(x) TRAIT0 * exp(x)))
  colnames(m) <- TRAITS
  q <- add_mutant(p, m, birth_rate = rep(1, nrow(m)))
  q$node_schedule_times <- rep(list(TIMES_INV), nrow(m))
  q
}

field_snaps <- function(scm) lapply(scm$history, function(h) {
  e <- h$state$env
  list(time = h$state$time, patch_density = h$state$patch_density,
       light = e$light_availability[, 1:2], soil = e$soil_moist)
})

run_one <- function(job) {
  f <- file.path(RUN_DIR, paste0(job$name, ".rds"))
  if (file.exists(f)) return(readRDS(f))
  lock <- sub("rds$", "lock", f)
  if (file.exists(lock)) return(list(ok = NA, job = job, secs = NA, err = "running elsewhere"))
  file.create(lock)
  on.exit(unlink(lock))
  p <- stand(job$lnb, job$dtrait)
  t0 <- proc.time()[["elapsed"]]
  out <- tryCatch({
    scm <- run_scm(p, mkenv(REGIME), ctrl(job$tol), run = FALSE)
    scm$collect <- isTRUE(job$pool)
    scm$run()
    res <- list(ok = TRUE, job = job, F = log(scm$net_reproduction_ratios),
                J = scm$offspring_production, steps = length(scm$ode_times))
    t1 <- proc.time()[["elapsed"]]
    if (isTRUE(job$pool)) {
      res$snaps <- field_snaps(scm)
      scm$collect <- FALSE
      scm$run_mutant(invaders(p))
      res$lnR <- log(scm$net_reproduction_ratios)
    }
    res$secs_resident <- t1 - t0
    res
  }, error = function(e) list(ok = FALSE, job = job, err = conditionMessage(e)))
  out$secs <- proc.time()[["elapsed"]] - t0
  saveRDS(out, f)
  out
}

zero <- setNames(rep(0, length(TRAITS)), TRAITS)
job <- function(name, lnb, dtrait = zero, tol = TOL, pool = TRUE)
  list(name = name, lnb = lnb, dtrait = dtrait, tol = tol, pool = pool)

eq_file <- file.path(RUN_DIR, "eq.rds")

if (STAGE == "eq") {
  lnb0 <- as.numeric(Sys.getenv("LNB0"))
  hs <- c(-1, 0, 1) * as.numeric(Sys.getenv("H", "0.2"))
  res <- mclapply(seq_along(hs), function(i)
    run_one(job(sprintf("eq_%+.3f", lnb0 + hs[i]), lnb0 + hs[i], pool = FALSE)),
    mc.cores = 3)
  f <- vapply(res, `[[`, 0, "F")
  print(data.frame(lnb = lnb0 + hs, F = f, secs = sapply(res, `[[`, "secs")))
  cf <- coef(lm(f ~ x + I(x^2), data.frame(x = hs, f = f)))
  rr <- polyroot(cf)
  r <- Re(rr[abs(Im(rr)) < 1e-9])
  r <- r[which.min(abs(r))]
  eq <- list(lnb_star = lnb0 + r, slope = cf[[2]] + 2 * cf[[3]] * r, F = f, h = hs,
             lnb0 = lnb0)
  print(eq)
  saveRDS(eq, eq_file)
}

if (STAGE == "runs") {
  lnb <- readRDS(eq_file)$lnb_star
  jobs <- list(job("base", lnb), job("null_b", lnb + 1e-6),
               job("base_tol", lnb, tol = TOL / 2))
  for (s in c(1, -1)) {
    tag <- if (s > 0) "p" else "m"
    jobs[[length(jobs) + 1]] <- job(paste0("lnb_", tag), lnb + s * DELTA)
    for (tr in TRAITS) {
      d <- zero; d[[tr]] <- s * DELTA
      jobs[[length(jobs) + 1]] <- job(paste0(tr, "_", tag), lnb, d)
    }
  }
  res <- mclapply(jobs, run_one, mc.cores = WORKERS, mc.preschedule = FALSE)
  for (r in res) cat(sprintf("%-22s ok %s  %.0f s  %s\n", r$job$name, r$ok, r$secs,
                             if (isTRUE(r$ok)) sprintf("steps %d  F %.6f  lnR'[1] %.6f", r$steps, r$F, r$lnR[1]) else r$err))
}
