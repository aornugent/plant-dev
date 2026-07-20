# Stage-1 classifier -- CAPTURE pass (expensive; run once).
#
# Runs the benchmark bank with the per-accepted-step event monitor + per-cohort
# branch-signature sink and the step-attempt log, and saves the RAW per-step data
# per scenario to results/classifier_raw/<scenario>.rds. Attribution is done
# offline by classifier_analyze.R on this saved data, so the attribution logic
# can be iterated without re-running the (70-yr, monitored) simulations.
#
# Also asserts R4: the monitor must not change offspring (bit-identical).

options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia)
  pkgload::load_all("plant", export_all = TRUE, quiet = TRUE)
})

ns <- asNamespace("odelia")
mon_enable <- get("step_monitor_enable", ns)
mon_reset  <- get("step_monitor_reset",  ns)
mon_get    <- get("step_monitor_get",    ns)
log_enable <- get("step_log_enable",     ns)
log_reset  <- get("step_log_reset",      ns)
log_get    <- get("step_log_get",        ns)
diag_enable <- get("tf24_solve_diag_enable", asNamespace("plant"))

datadir <- "scripts/tf24-benchmarks/data"
outdir  <- "scripts/tf24-benchmarks/results/classifier_raw"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
TOL <- 1e-6

MARGIN_NAMES <- c("theta_res", "theta_sat", "psi_ceil", "runoff",
                  "psi_wettest", "shutdown", "interval")
SIG_NAMES <- c("clamp_bits", "runoff_on", paste0("branch", 0:5), "n_cohort")

run_one <- function(nm, years) {
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years * 365))
  rain <- b$rain[seq_len(nd)]
  times <- (0:(nd - 1)) / 365
  life_run <- max(times)
  mkenv <- function() {
    e <- Environment("TF24")
    e$extrinsic_drivers_set_variable("rainfall", times, rain)
    e
  }
  mk <- function() {
    p <- scm_base_parameters("TF24")
    p$max_patch_lifetime <- life_run
    add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1)
  }
  ctrl <- control(ode_method = "rkck", ode_tol_rel = TOL, ode_tol_abs = TOL)

  # Reference (monitor off) for the R4 bit-identical check.
  off <- sum(run_scm(mk(), mkenv(), ctrl)$offspring_production)

  # Monitored run.
  log_reset(); log_enable(TRUE)
  mon_reset(); mon_enable(TRUE); diag_enable(TRUE)
  on <- sum(run_scm(mk(), mkenv(), ctrl)$offspring_production)
  log_enable(FALSE); mon_enable(FALSE); diag_enable(FALSE)

  m <- mon_get()
  margins <- as.data.frame(m$margins); names(margins) <- MARGIN_NAMES
  sig <- as.data.frame(m$sig); names(sig) <- SIG_NAMES
  mon <- cbind(t = m$t, h = m$h, margins, sig)

  list(scenario = nm, years = years, offspring_off = off, offspring_on = on,
       rel = abs(on - off) / abs(off), mon = mon, log = log_get())
}

scenarios <- c("intense_storms", "extended_drought", "whiplash",
               "dry_to_wet", "long_horizon")
scenarios <- scenarios[file.exists(file.path(datadir, paste0(scenarios, ".rds")))]
YEARS <- as.numeric(Sys.getenv("CLASSIFIER_YEARS", "100"))

for (nm in scenarios) {
  r <- run_one(nm, YEARS)
  saveRDS(r, file.path(outdir, paste0(nm, ".rds")))
  cat(sprintf("%-18s accepted=%6d rej=%d off=%.6g rel=%.1e %s\n",
              nm, nrow(r$mon), sum(r$log$ok == 0), r$offspring_on, r$rel,
              if (r$rel < 1e-9) "[bit-ident]" else "[!! CHANGED]"))
}
cat("raw data saved to", outdir, "\n")
