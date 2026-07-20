# Ladder rung 2b (the norm-safety join). For each ACCEPTED step, the monitor now
# records the weight rho and the species-weight-fraction of the member that
# attained rmax (the adaptive error-norm maximiser). Question: is the
# error-limiting member J-relevant (dominant, high rho-fraction -> must keep
# full weight, no gain from a J-weighted norm) or marginal (low fraction ->
# downweight it, big win) -- and how many marginal ones sit near the rho->0
# removal boundary (must guard)?
#
# margins columns (1-indexed in R): 8 = rmax-attaining member rho, 9 = its
# fraction of species total weight. NaN when the attainer was a reservoir.

options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                     export_all = TRUE, quiet = TRUE)
})
ns <- asNamespace("odelia")
mon_enable <- get("step_monitor_enable", ns); mon_reset <- get("step_monitor_reset", ns)
mon_get <- get("step_monitor_get", ns)
diag_enable <- get("tf24_solve_diag_enable", asNamespace("plant"))
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
TOL <- 1e-6

run_one <- function(nm, years) {
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years * 365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd - 1)) / 365
  e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain)
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- max(times)
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1)
  ctrl <- control(ode_method = "rkck", ode_tol_rel = TOL, ode_tol_abs = TOL)
  mon_reset(); mon_enable(TRUE); diag_enable(TRUE)
  scm <- run_scm(p, e, ctrl)
  mon_enable(FALSE); diag_enable(FALSE)
  m <- mon_get()$margins
  list(J = sum(scm$offspring_production), rho = m[, 8], frac = m[, 9])
}

scen <- list(intense_storms = 15, dry_to_wet = 15, extended_drought = 25)
rows <- list()
for (nm in names(scen)) {
  r <- run_one(nm, scen[[nm]])
  is_member <- !is.na(r$frac)
  f <- r$frac[is_member]
  rows[[nm]] <- data.frame(
    scenario = nm, n_acc = length(r$frac),
    pct_member = 100 * mean(is_member),        # attainer is a member (vs reservoir)
    frac_med = median(f), frac_p90 = as.numeric(quantile(f, 0.90)),
    pct_marginal_lt01 = 100 * mean(f < 0.01),  # <1% of species weight
    pct_marginal_lt10 = 100 * mean(f < 0.10),
    pct_dominant_gt50 = 100 * mean(f > 0.50))
  cat(sprintf("%-16s n_acc=%d pct_member=%.1f  frac med=%.4f p90=%.3f  <1%%=%.1f <10%%=%.1f >50%%=%.1f\n",
      nm, length(r$frac), 100*mean(is_member), median(f),
      quantile(f,0.9), 100*mean(f<0.01), 100*mean(f<0.10), 100*mean(f>0.5)))
  flush(stdout())
  saveRDS(r, file.path(outdir, paste0("argmax_safety_", nm, ".rds")))
}
S <- do.call(rbind, rows); rownames(S) <- NULL
saveRDS(S, file.path(outdir, "argmax_safety_summary.rds"))
cat("\npct_member = accepted steps whose rmax attainer is a member (else reservoir).",
    "\nfrac = attainer's fraction of its species' weight. Low frac => marginal",
    "\n(J-irrelevant, downweight candidate); >50% => dominant (must keep weight).",
    "\nIf attainers are mostly marginal => the J-weighted norm has room; if mostly",
    "\ndominant => the norm already controls J-relevant members, little to gain.\n")
cat("ALLDONE\n")
