# Capture pass for the lineage decomposition: run each REFINED scheme once and
# save {tau, g(weighted), fec, J} to disk. Skips a scheme whose file already
# exists (warm start / crash-resume). Cheap re-analysis then reads these.
#
# Scheme = adaptively refined node schedule at a given schedule_eps
# (refine_schedule=TRUE). Two eps per scenario => two converged meshes with
# different member-insertion histories.

options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                     export_all = TRUE, quiet = TRUE)
})
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results/deltaJ_schemes"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
TOL <- 1e-6

capture_one <- function(nm, years, eps) {
  tag <- sprintf("%s_eps%.0e", nm, eps)
  f <- file.path(outdir, paste0(tag, ".rds"))
  if (file.exists(f)) { cat("skip (exists):", tag, "\n"); return(invisible()) }
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years * 365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd - 1)) / 365
  e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain)
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- max(times)
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1)
  ctrl <- control(ode_method = "rkck", ode_tol_rel = TOL, ode_tol_abs = TOL,
                  schedule_eps = eps, schedule_nsteps = 30)
  scm <- run_scm(p, e, ctrl, refine_schedule = TRUE)
  sp <- scm$patch$species[[1]]
  res <- list(scenario = nm, eps = eps, years = years,
              J = sum(scm$offspring_production),
              tau = sp$node_times,
              fec = sp$net_reproduction_ratio_by_node,
              pdens = sp$patch_densities)
  saveRDS(res, f)
  cat(sprintf("saved %s : n=%d J=%.6e\n", tag, length(res$tau), res$J))
}

# order cheapest-first so a kill still leaves useful pairs
jobs <- list(
  c("intense_storms", 20, 2e-2), c("intense_storms", 20, 2e-3),
  c("dry_to_wet",     25, 2e-2), c("dry_to_wet",     25, 2e-3))
for (j in jobs) capture_one(j[1], as.numeric(j[2]), as.numeric(j[3]))
cat("CAPTURE DONE\n")
