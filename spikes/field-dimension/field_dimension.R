# Pilot estimate of d, the effective dimension of TF24's competitive field.
#
# One TF24 resident near demographic equilibrium on a rainfall record. Each run
# moves one resident input (ln b or a trait, by +-DELTA) and carries a pool of
# invaders at a negligible birth rate, so the run records both sides at once:
#   making:  the field the resident makes (light by height and patch age, soil
#            water by depth and patch age), read off the collected snapshots;
#   sensing: each invader's ln R', its invasion fitness in that field.
# The installed plant's run_mutant() is a stub, so invaders ride in the
# resident run instead of replaying its record.
#
#   STAGE=eq    REGIME=long-drought Rscript field_dimension.R   # b* by a secant chord
#   STAGE=runs  REGIME=long-drought Rscript field_dimension.R   # the perturbation runs
#   STAGE=fit   REGIME=long-drought Rscript field_dimension.R   # matrices and SVDs
#
# Each run is saved on its own under RUN_DIR, so a crash loses one run.
Sys.setenv(PLANT_LIB = "/home/a/R/x86_64-pc-linux-gnu-library/4.6")
Sys.setenv(LIFETIME = Sys.getenv("LIFETIME", "40"))
source("/home/a/dev/plant-dev/.claude/worktrees/workflows/harness/long_drought.R")
suppressMessages(library(parallel))

HERE <- "/home/a/dev/plant-dev/.claude/worktrees/workflows/spikes/field-dimension"
REGIME <- Sys.getenv("REGIME", "long-drought")
STAGE <- Sys.getenv("STAGE", "runs")
WORKERS <- as.integer(Sys.getenv("WORKERS", "9"))
RUN_DIR <- file.path("/home/a/.claude/jobs/9d586e52/tmp/runs", REGIME)
dir.create(RUN_DIR, recursive = TRUE, showWarnings = FALSE)

TOL <- 1e-4
DELTA <- as.numeric(Sys.getenv("DELTA", "0.2"))
B_INV <- 1e-8
TIMES <- uniform_times(108)
TIMES_INV <- TIMES[seq(1, 108, 3)]

ctrl <- function(tol = TOL) {
  ct <- control()
  ct$ode_tol_rel <- tol
  ct$ode_tol_abs <- tol * 1e-4
  ct$node_density_in_birth_date <- TRUE
  ct
}

# The resident's traits as ln-multiples of the stand's: lma = 0.32 and every
# other at TF24's default, through the hyperparameterisation.
TRAITS <- c("lma", "rho", "hmat", "K_s", "rooting_depth_max", "vcmax_25")
base_traits <- function() {
  d <- scm_base_parameters("TF24")$strategy_default$pars
  v <- vapply(TRAITS, function(n) d[[n]], 0)
  v[["lma"]] <- LMA0
  v
}
TRAIT0 <- base_traits()

# The invader pool: the resident's own traits first (the identity check), then
# a Latin hypercube in ln-trait over +-0.4 in the five traits that most plausibly
# separate (light by height and age; water by depth and time).
POOL_TRAITS <- c("lma", "rho", "hmat", "K_s", "rooting_depth_max")
pool <- local({
  set.seed(20261023)
  n <- 15
  x <- sapply(POOL_TRAITS, function(.) (sample(n) - runif(n)) / n * 0.8 - 0.4)
  rbind(0, x)
})

stand <- function(lnb, dtrait = setNames(rep(0, length(TRAITS)), TRAITS),
                  with_pool = TRUE) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  tr <- TRAIT0 * exp(dtrait)
  m <- trait_matrix(tr, TRAITS)
  b <- exp(lnb)
  times <- list(TIMES)
  if (with_pool) {
    inv <- t(apply(pool, 1, function(x) {
      v <- TRAIT0
      v[POOL_TRAITS] <- v[POOL_TRAITS] * exp(x)
      v
    }))
    colnames(inv) <- TRAITS
    m <- rbind(m, inv)
    b <- c(b, rep(B_INV, nrow(inv)))
    times <- c(times, rep(list(TIMES_INV), nrow(inv)))
  }
  p <- add_strategies(p, m, birth_rate = b)
  p$node_schedule_times <- times
  p
}

# One run: offspring per seed of every species, and the field at each snapshot.
run_one <- function(job) {
  f <- file.path(RUN_DIR, paste0(job$name, ".rds"))
  if (file.exists(f)) return(readRDS(f))
  lock <- sub("rds$", "lock", f)
  if (file.exists(lock)) return(list(ok = NA, job = job, secs = NA, err = "running elsewhere"))
  file.create(lock)
  on.exit(unlink(lock))
  p <- stand(job$lnb, job$dtrait, job$with_pool)
  t0 <- proc.time()[["elapsed"]]
  out <- tryCatch({
    scm <- plant:::SCM("TF24", "TF24_Env")(p, mkenv(REGIME), ctrl(job$tol))
    scm$collect <- TRUE
    scm$run()
    snaps <- lapply(scm$history, function(h) {
      e <- h$state$env
      list(time = h$state$time, patch_density = h$state$patch_density,
           light = e$light_availability[, 1:2], soil = e$soil_moist)
    })
    list(ok = TRUE, job = job, R = scm$net_reproduction_ratios,
         J = scm$offspring_production, steps = length(scm$ode_times),
         snaps = snaps)
  }, error = function(e) list(ok = FALSE, job = job, err = conditionMessage(e)))
  out$secs <- proc.time()[["elapsed"]] - t0
  saveRDS(out, f)
  out
}

zero <- setNames(rep(0, length(TRAITS)), TRAITS)
job <- function(name, lnb, dtrait = zero, tol = TOL, with_pool = TRUE)
  list(name = name, lnb = lnb, dtrait = dtrait, tol = tol, with_pool = with_pool)

eq_file <- file.path(RUN_DIR, "eq.rds")

if (STAGE == "eq") {
  lnb0 <- as.numeric(Sys.getenv("LNB0", log(4.68)))
  hs <- c(-1, 0, 1) * as.numeric(Sys.getenv("H", "0.3"))
  res <- mclapply(seq_along(hs), function(i)
    run_one(job(sprintf("eq_%d", i), lnb0 + hs[i], with_pool = FALSE)),
    mc.cores = 3)
  f <- vapply(res, function(r) log(r$J[1]) - r$job$lnb, 0)
  print(data.frame(lnb = lnb0 + hs, f = f, secs = sapply(res, `[[`, "secs")))
  fit <- lm(f ~ x + I(x^2), data.frame(x = hs, f = f))
  cf <- coef(fit)
  r <- if (abs(cf[3]) > 1e-12) {
    rr <- polyroot(cf)
    rr <- Re(rr[abs(Im(rr)) < 1e-9])
    rr[which.min(abs(rr))]
  } else -cf[1] / cf[2]
  eq <- list(lnb_star = lnb0 + r, slope = cf[2] + 2 * cf[3] * r, f = f, h = hs)
  print(eq)
  saveRDS(eq, eq_file)
}

if (STAGE == "runs") {
  eq <- readRDS(eq_file)
  lnb <- eq$lnb_star
  jobs <- list(job("base", lnb), job("base_tol", lnb, tol = TOL / 2),
               job("null_b", lnb + 1e-6))
  for (s in c(1, -1)) {
    tag <- if (s > 0) "p" else "m"
    jobs[[length(jobs) + 1]] <- job(paste0("lnb_", tag), lnb + s * DELTA)
    for (tr in TRAITS) {
      d <- zero; d[[tr]] <- s * DELTA
      jobs[[length(jobs) + 1]] <- job(paste0(tr, "_", tag), lnb, d)
    }
  }
  if (Sys.getenv("REVERSE") == "1") jobs <- rev(jobs)
  res <- mclapply(jobs, run_one, mc.cores = WORKERS, mc.preschedule = FALSE)
  for (r in res) cat(sprintf("%-22s ok %s  %.0f s  %s\n", r$job$name, r$ok, r$secs,
                             if (isTRUE(r$ok)) sprintf("steps %d  ln R'[1] %.6f", r$steps, log(r$R[2])) else r$err))
}

if (STAGE == "fit") {
  eq <- readRDS(eq_file)
  rd <- function(n) {
    f <- file.path(RUN_DIR, paste0(n, ".rds"))
    if (file.exists(f)) readRDS(f) else list(ok = FALSE, secs = NA)
  }
  base <- rd("base")
  cols <- c("lnb", TRAITS)
  lnR <- function(r) log(r$R[-1])           # the pool's ln R'
  plus <- lapply(cols, function(c) rd(paste0(c, "_p")))
  minus <- lapply(cols, function(c) rd(paste0(c, "_m")))
  # A column with one side missing falls back to a one-sided difference: the
  # base run stands in for the missing side at half the step.
  base_side <- function(r) if (isTRUE(r$ok)) r else NULL
  ok <- vapply(seq_along(cols), function(i) isTRUE(plus[[i]]$ok) || isTRUE(minus[[i]]$ok), TRUE)
  two_sided <- vapply(seq_along(cols), function(i) isTRUE(plus[[i]]$ok) && isTRUE(minus[[i]]$ok), TRUE)
  cat("columns:", paste0(cols, ifelse(two_sided, "", ifelse(ok, "(one-sided)", "(missing)"))), "\n")
  cols <- cols[ok]; plus <- plus[ok]; minus <- minus[ok]; two_sided <- two_sided[ok]
  step <- ifelse(two_sided, 2 * DELTA, DELTA)
  for (i in seq_along(cols)) {
    if (!isTRUE(plus[[i]]$ok)) plus[[i]] <- base
    if (!isTRUE(minus[[i]]$ok)) minus[[i]] <- base
  }

  # Sensing: central differences per unit ln, and their second differences.
  Phi0 <- lnR(base)
  dPhi <- sapply(seq_along(cols), function(i) (lnR(plus[[i]]) - lnR(minus[[i]])) / step[i])
  curv <- sapply(seq_along(cols), function(i)
    if (two_sided[i]) (lnR(plus[[i]]) + lnR(minus[[i]]) - 2 * Phi0) / 2 else NA * Phi0)
  colnames(dPhi) <- colnames(curv) <- cols
  # Noise: a 1e-6 move in ln b and a halved tolerance, per entry of ln R'.
  e_null <- lnR(rd("null_b")) - Phi0
  e_tol <- lnR(rd("base_tol")) - Phi0
  eps <- sqrt(mean(c(e_null, e_tol)^2))
  # A central-difference entry carries sqrt(2) eps / (2 DELTA); the largest
  # singular value of an n x m noise matrix is about sigma (sqrt(n) + sqrt(m)).
  # The two noise vectors are nearly parallel: the error is one field direction,
  # not independent per invader. So the floor is the 95% quantile of the top
  # singular value of noise matrices whose every run carries a random
  # combination of the two observed errors.
  # Two floors: the jitter a 1e-6 move in ln b exposes (what differences at
  # one tolerance carry), and that with the halved tolerance's shift added (an
  # upper bound, since a tolerance bias common to all runs cancels).
  sv_floor <- function(E) {
    set.seed(1)
    draws <- replicate(2000, {
      run_err <- function() E %*% rnorm(ncol(E), sd = sqrt(1 / ncol(E)))
      N <- sapply(seq_along(cols), function(i)
        (run_err() - if (two_sided[i]) run_err() else 0) / step[i])
      svd(N, 0, 0)$d[1]
    })
    unname(quantile(draws, 0.95))
  }
  E2 <- cbind(e_null, e_tol)
  floor_jitter <- sv_floor(cbind(e_null))
  floor_sv <- sv_floor(E2)
  # The sensing matrix with the noise directions projected out of its columns.
  Q <- qr.Q(qr(E2))
  sv_proj <- svd(dPhi - Q %*% crossprod(Q, dPhi))$d
  sv <- svd(dPhi)
  rel <- sv$d / sv$d[1]
  dcount <- function(x, thr) sum(x > thr)
  sens <- list(Phi0 = Phi0, dPhi = dPhi, curv = curv, eps = eps, e_null = e_null,
               e_tol = e_tol, floor_sv = floor_sv, sv = sv$d, rel = rel,
               U = sv$u, V = sv$v,
               d = sapply(c(1e-1, 1e-2, 1e-3), function(t) dcount(rel, t)),
               d_above_noise = dcount(sv$d, floor_sv), sv_proj = sv_proj,
               floor_jitter = floor_jitter, d_above_jitter = dcount(sv$d, floor_jitter),
               noise_cos = sum(e_null * e_tol) / sqrt(sum(e_null^2) * sum(e_tol^2)))
  # Column-normalised: each perturbation scaled to unit norm, so the rank does
  # not lean on which inputs move the field most.
  dn <- sweep(dPhi, 2, sqrt(colSums(dPhi^2)), "/")
  svn <- svd(dn)
  sens$sv_norm <- svn$d
  sens$V_norm <- svn$v
  # Centred over the pool: drops the mode that moves every invader alike.
  dc <- scale(dPhi, center = TRUE, scale = FALSE)
  sens$sv_centred <- svd(dc)$d

  # Making: the field on a common grid, weighted by patch density.
  hgrid <- seq(0, 30, length.out = 61)
  field <- function(r) {
    tt <- vapply(r$snaps, `[[`, 0, "time")
    pd <- vapply(r$snaps, `[[`, 0, "patch_density")
    L <- t(vapply(r$snaps, function(s) {
      l <- s$light
      approx(l[, 1], l[, 2], hgrid, rule = 2)$y
    }, hgrid))
    W <- t(vapply(r$snaps, `[[`, numeric(5), "soil"))
    list(t = tt, pd = pd, L = L, W = W)
  }
  F0 <- field(base)
  tgrid <- F0$t
  onto <- function(Fr) {
    if (length(Fr$t) == length(tgrid) && max(abs(Fr$t - tgrid)) < 1e-9) return(Fr)
    Fr$L <- apply(Fr$L, 2, function(y) approx(Fr$t, y, tgrid, rule = 2)$y)
    Fr$W <- apply(Fr$W, 2, function(y) approx(Fr$t, y, tgrid, rule = 2)$y)
    Fr
  }
  wt <- sqrt(F0$pd * c(diff(tgrid), mean(diff(tgrid))))
  dfield <- function(i) {
    a <- onto(field(plus[[i]])); b <- onto(field(minus[[i]]))
    list(L = (a$L - b$L) * wt / step[i], W = (a$W - b$W) * wt / step[i])
  }
  dF <- lapply(seq_along(cols), dfield)
  ML <- sapply(dF, function(x) as.vector(x$L))
  MW <- sapply(dF, function(x) as.vector(x$W))
  colnames(ML) <- colnames(MW) <- cols
  a <- onto(field(rd("null_b")))
  null_norm <- c(L = sqrt(sum(((a$L - F0$L) * wt)^2)), W = sqrt(sum(((a$W - F0$W) * wt)^2)))
  M <- rbind(ML / sqrt(sum(ML^2)), MW / sqrt(sum(MW^2)))
  svL <- svd(ML); svW <- svd(MW); svM <- svd(M)
  making <- list(hgrid = hgrid, tgrid = tgrid, pd = F0$pd, L0 = F0$L, W0 = F0$W,
                 ML = ML, MW = MW, svL = svL$d, svW = svW$d, svM = svM$d,
                 VL = svL$v, VW = svW$v, VM = svM$v,
                 UL1 = matrix(svL$u[, 1], length(tgrid)), UL2 = matrix(svL$u[, 2], length(tgrid)),
                 UW1 = matrix(svW$u[, 1], length(tgrid)),
                 null_norm = null_norm)

  out <- list(regime = REGIME, eq = eq, delta = DELTA, tol = TOL, b_inv = B_INV,
              traits = TRAITS, trait0 = TRAIT0, pool = pool, cols = cols,
              two_sided = two_sided, sensing = sens, making = making,
              secs = sapply(c("base", "base_tol", "null_b", paste0(c("lnb", TRAITS), "_p"), paste0(c("lnb", TRAITS), "_m")),
                            function(n) rd(n)$secs))
  saveRDS(out, file.path(HERE, sprintf("field_dimension_%s.rds", REGIME)))

  f6 <- function(x) paste(formatC(x, digits = 3, format = "g"), collapse = "  ")
  cat("\n==", REGIME, " ln b* =", eq$lnb_star, " slope", eq$slope, "\n")
  cat("Phi0 (pool ln R'):", f6(Phi0), "\n")
  cat("noise eps per ln R' entry:", eps, " (null_b rms", sqrt(mean(e_null^2)),
      ", tol rms", sqrt(mean(e_tol^2)), ")  sv floor", floor_sv, "\n")
  cat("dPhi sv:", f6(sv$d), "\n rel:", f6(rel), "\n d at 1e-1,1e-2,1e-3:", sens$d,
      " above noise:", sens$d_above_noise, " above jitter floor", floor_jitter, ":", sens$d_above_jitter, "\n")
  cat("noise vectors cos", sens$noise_cos, "; sv with noise span projected out:", f6(sv_proj), "\n")
  cat("col-normalised sv rel:", f6(svn$d / svn$d[1]), "\n")
  cat("centred sv rel:", f6(sens$sv_centred / sens$sv_centred[1]), "\n")
  cat("curvature / slope*DELTA (nonlinearity) by column:",
      f6(sqrt(colSums(curv^2)) / sqrt(colSums((dPhi * DELTA)^2))), "\n")
  cat("light sv rel:", f6(svL$d / svL$d[1]), "\n")
  cat("water sv rel:", f6(svW$d / svW$d[1]), "\n")
  cat("joint sv rel:", f6(svM$d / svM$d[1]), "\n")
  cat("null-move field norms (vs column norms):", f6(making$null_norm), " | ",
      f6(sqrt(colSums(ML^2)) * step), "|", f6(sqrt(colSums(MW^2)) * step), "\n")
  cat("sensing right vectors (columns = modes):\n"); print(round(sv$v, 3))
  cat("dPhi:\n"); print(round(dPhi, 3))
}
