# Oracle test E2 -- tolerance-iteration crossing (solver-level, decisive), across
# the FULL rainfall bank. If the 27-35% rejection waste is the controller bisecting
# against the inner argmax's resolution floor eps_p ~ GSS_tol_abs, then tightening
# the inner search (smaller GSS_tol_abs, SAME outer ode tolerance) must collapse the
# rejection fraction and raise min-h, while leaving offspring (J) unchanged. If
# reject fraction is invariant in GSS_tol_abs, the mechanism is refuted.
#
# Writes each result line to a CSV immediately (progress visible while running).
# Zero production change: GSS_tol_abs is a control() field; outer tol fixed 1e-6.

options(pkg.build_extra_flags = FALSE)
suppressMessages({ library(odelia); pkgload::load_all("plant", export_all = TRUE, quiet = TRUE) })
ns <- asNamespace("odelia")
log_enable <- get("step_log_enable", ns); log_reset <- get("step_log_reset", ns); log_get <- get("step_log_get", ns)

datadir <- "scripts/tf24-benchmarks/data"
OUTER_TOL <- 1e-6
CSV <- "scripts/tf24-benchmarks/results/noise_floor_E2_bank.csv"
YEARS_CAP <- as.numeric(Sys.getenv("E2_YEARS", "12"))
TOLS <- c(1e-3, 1e-6)

# all bank scenarios that exist, plus drydown if present
scen <- c("intense_storms", "extended_drought", "whiplash", "dry_to_wet", "long_horizon", "drydown")
scen <- scen[file.exists(file.path(datadir, paste0(scen, ".rds")))]

cat("scenario,gss_tol,years,attempts,accepted,reject_frac,min_h_days,offspring,wall_s\n", file = CSV)
cat(sprintf("=== E2 bank: reject_frac vs GSS_tol_abs (outer_tol=%.0e, years<=%g) ===\n\n", OUTER_TOL, YEARS_CAP))

run_at <- function(nm, gss_tol) {
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  years <- min(YEARS_CAP, length(b$rain) / 365)
  nd <- min(length(b$rain), round(years * 365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd - 1)) / 365
  e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain)
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- max(times)
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1)
  ct <- control(ode_method = "rkck", ode_tol_rel = OUTER_TOL, ode_tol_abs = OUTER_TOL, GSS_tol_abs = gss_tol)
  log_reset(); log_enable(TRUE); t0 <- proc.time()[[3]]
  off <- sum(run_scm(p, e, ct)$offspring_production); wall <- proc.time()[[3]] - t0
  log_enable(FALSE); d <- as.data.frame(log_get())
  list(nm = nm, gss_tol = gss_tol, years = years, n_attempt = nrow(d),
       n_accept = sum(d$ok == 1), reject_frac = mean(d$ok == 0),
       min_h_days = min(d$h) * 365, offspring = off, wall = wall)
}

for (nm in scen) for (tol in TOLS) {
  r <- tryCatch(run_at(nm, tol), error = function(e) { message("FAIL ", nm, " ", tol, ": ", conditionMessage(e)); NULL })
  if (is.null(r)) next
  cat(sprintf("%s,%.0e,%.1f,%d,%d,%.4f,%.4g,%.10g,%.1f\n",
              r$nm, r$gss_tol, r$years, r$n_attempt, r$n_accept, r$reject_frac,
              r$min_h_days, r$offspring, r$wall), file = CSV, append = TRUE)
  cat(sprintf("%-18s GSS=%.0e yr=%.0f | reject=%.3f min_h=%.3g d | off=%.8g | %.0fs\n",
              r$nm, r$gss_tol, r$years, r$reject_frac, r$min_h_days, r$offspring, r$wall))
  flush.console()
}
cat("\ndone -> ", CSV, "\n")
