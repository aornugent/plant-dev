# Test 2 (item D): rmax-component churn log. Does the state component that sets
# the adaptive error norm (rmax) reshuffle step-to-step? If yes -> the reject
# statistics are extreme-value statistics of a max over a growing block, the
# PI-controller failure is explained, and a J-relevance-weighted (goal-oriented)
# norm is the lever that could cut ACCEPTED steps. If the argmax is stable /
# dominated by the soil block -> a different story.
#
# Uses the new odelia norm-argmax log (step_argmax_*, bit-identical off).
# State layout is [members | soil]; soil = last env_size indices.

options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia); pkgload::load_all("plant", export_all = TRUE, quiet = TRUE)
})
ns <- asNamespace("odelia")
am_enable <- get("step_argmax_enable", ns)
am_reset  <- get("step_argmax_reset",  ns)
am_get    <- get("step_argmax_get",    ns)

datadir <- "scripts/tf24-benchmarks/data"
outdir  <- "scripts/tf24-benchmarks/results/argmax_raw"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
TOL <- 1e-6
scen <- list(
  extended_drought = 100, dry_to_wet = 25, intense_storms = 25,
  long_horizon = 70, whiplash = 30)

# env (soil) ODE size, queried once
env_size <- tryCatch(Environment("TF24")$ode_size, error = function(e) 5L)
cat("TF24 environment ode_size (soil block) =", env_size, "\n\n")

run_one <- function(nm, years) {
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years * 365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd - 1)) / 365
  mkenv <- function() { e <- Environment("TF24")
    e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  mk <- function() { p <- scm_base_parameters("TF24")
    p$max_patch_lifetime <- max(times)
    add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1) }
  ctrl <- control(ode_method = "rkck", ode_tol_rel = TOL, ode_tol_abs = TOL)
  am_reset(); am_enable(TRUE)
  invisible(run_scm(mk(), mkenv(), ctrl))
  am_enable(FALSE)
  am_get()
}

summ <- list()
for (nm in names(scen)) {
  d <- run_one(nm, scen[[nm]])
  saveRDS(d, file.path(outdir, paste0(nm, ".rds")))
  d$is_soil <- d$i >= (d$dim - env_size)           # soil = last env_size idx
  rej <- d[d$ok == 0, ]; acc <- d[d$ok == 1, ]
  churn <- function(x) if (nrow(x) > 1)
    mean(x$i[-1] != x$i[-nrow(x)]) else NA          # frac of steps argmax moved
  ndist <- function(x) length(unique(x$i))
  # normalised entropy of the argmax index distribution (1 = uniform churn)
  ent <- function(x) { p <- table(x$i)/nrow(x)
    if (length(p) <= 1) 0 else -sum(p*log(p))/log(length(p)) }
  summ[[nm]] <- data.frame(
    scenario = nm, n_att = nrow(d), rej_pct = 100*mean(d$ok==0),
    maxdim = max(d$dim),
    churn_all = churn(d), churn_rej = churn(rej),
    ndistinct_rej = ndist(rej), entropy_rej = ent(rej),
    soil_pct_all = 100*mean(d$is_soil),
    soil_pct_rej = 100*mean(rej$is_soil),
    soil_pct_acc = 100*mean(acc$is_soil))
}
S <- do.call(rbind, summ); rownames(S) <- NULL
print(S, digits = 3)
saveRDS(S, "scripts/tf24-benchmarks/results/argmax_churn_summary.rds")
cat("\nchurn_* = frac of consecutive attempts where the rmax component index",
    "changed;\nndistinct_rej/entropy_rej = # distinct rmax components among",
    "rejects & their\nnormalised entropy (1=fully churning); soil_pct_* = frac",
    "of attempts where\nrmax is a soil component (vs a member).\n")
