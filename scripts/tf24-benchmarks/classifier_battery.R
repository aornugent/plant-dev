# Stage-1 classifier -- STRESS BATTERY capture.
#
# Extends the single-species TF24 capture with the coverage the first gate run
# lacked: the whole-profile drydown scenario, the TF24f model variant (tracked-p
# replaces the argmax -- tests whether the GSS/interval signal is the lever), and
# a multispecies assembly (the R3 non-finite failure case). Saves raw per-step
# data tagged <model>__<label>.rds; attribution is classifier_analyze.R.
#
# Multispecies may go non-finite (known H1 failure) -- wrapped so the battery
# continues and records how far it got.

options(pkg.build_extra_flags = FALSE)
suppressMessages({ library(odelia); pkgload::load_all("plant", export_all = TRUE, quiet = TRUE) })

ns <- asNamespace("odelia")
mon_enable <- get("step_monitor_enable", ns); mon_reset <- get("step_monitor_reset", ns)
mon_get <- get("step_monitor_get", ns)
log_enable <- get("step_log_enable", ns); log_reset <- get("step_log_reset", ns)
log_get <- get("step_log_get", ns)
diag_enable <- get("tf24_solve_diag_enable", asNamespace("plant"))

datadir <- "scripts/tf24-benchmarks/data"
outdir  <- "scripts/tf24-benchmarks/results/classifier_raw"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
TOL <- 1e-6
MARGIN_NAMES <- c("theta_res","theta_sat","psi_ceil","runoff","psi_wettest","shutdown","interval")
SIG_NAMES <- c("clamp_bits","runoff_on", paste0("branch",0:5), "n_cohort")

# lma vector: 1 value = single species; several = multispecies assembly.
run_job <- function(model, scenario, lma) {
  b <- readRDS(file.path(datadir, paste0(scenario, ".rds")))
  rain <- b$rain; nd <- length(rain); times <- (0:(nd - 1)) / 365
  mkenv <- function() { e <- Environment("TF24")
    e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  mk <- function() { p <- scm_base_parameters(model); p$max_patch_lifetime <- max(times)
    add_strategies(p, trait_matrix(lma, "lma"), birth_rate = rep(1, length(lma))) }
  ctrl <- control(ode_method = "rkck", ode_tol_rel = TOL, ode_tol_abs = TOL)

  off <- tryCatch(sum(run_scm(mk(), mkenv(), ctrl)$offspring_production),
                  error = function(e) NA_real_)
  log_reset(); log_enable(TRUE); mon_reset(); mon_enable(TRUE); diag_enable(TRUE)
  err <- NULL
  on <- tryCatch(sum(run_scm(mk(), mkenv(), ctrl)$offspring_production),
                 error = function(e) { err <<- conditionMessage(e); NA_real_ })
  log_enable(FALSE); mon_enable(FALSE); diag_enable(FALSE)

  m <- mon_get()
  margins <- as.data.frame(m$margins); if (ncol(margins)) names(margins) <- MARGIN_NAMES
  sig <- as.data.frame(m$sig); if (ncol(sig)) names(sig) <- SIG_NAMES
  mon <- if (length(m$t)) cbind(t = m$t, h = m$h, margins, sig) else NULL
  list(scenario = paste0(model, "__", scenario), model = model, base_scenario = scenario,
       n_species = length(lma), offspring_off = off, offspring_on = on,
       rel = if (is.na(off) || is.na(on)) NA else abs(on - off) / abs(off),
       mon = mon, log = log_get(), err = err)
}

# --- the battery (reuses the 5 TF24 single-species runs already captured) -----
LMA1 <- 0.0825
LMA4 <- c(0.0825, 0.1250, 0.1978, 0.2600)   # 4-species assembly
jobs <- list(
  list("TF24",  "drydown",          LMA1),  # maximal dry-end stress, TF24
  list("TF24f", "extended_drought", LMA1),  # model variant on hard dry
  list("TF24f", "whiplash",         LMA1),
  list("TF24f", "drydown",          LMA1),
  list("TF24f", "long_horizon",     LMA1),
  list("TF24",  "extended_drought", LMA4),  # multispecies (R3 failure) TF24
  list("TF24f", "extended_drought", LMA4)   # multispecies TF24f
)

# CLASSIFIER_JOBS env var: "multispp" runs only the multispecies jobs; else all.
if (identical(Sys.getenv("CLASSIFIER_JOBS"), "multispp")) {
  jobs <- Filter(function(j) length(j[[3]]) > 1, jobs)
}

for (j in jobs) {
  r <- run_job(j[[1]], j[[2]], j[[3]])
  saveRDS(r, file.path(outdir, paste0(r$scenario,
          if (r$n_species > 1) "__multispp" else "", ".rds")))
  cat(sprintf("%-28s spp=%d accepted=%7s rej=%7s off=%.4g rel=%s %s\n",
              r$scenario, r$n_species,
              if (is.null(r$mon)) "0" else nrow(r$mon),
              format(sum(r$log$ok == 0)), r$offspring_on,
              if (is.na(r$rel)) "NA" else formatC(r$rel, format = "e", digits = 1),
              if (!is.null(r$err)) paste0("[", r$err, "]")
              else if (!is.na(r$rel) && r$rel < 1e-9) "[bit-ident]" else "[!!]"))
}
cat("battery raw saved to", outdir, "\n")
