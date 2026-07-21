# Rung 2, first decisive test: does a SINGLE-solve g(tau) hierarchical-surplus
# indicator predict where the fixed->refined J-error actually concentrates on the
# lineage axis? If yes, goal-oriented placement is fundable (the indicator is a
# cheap surrogate for the >15-min refiner); if no, placement needs the feedback
# iteration. Run across the bank's measure-stressing scenarios (survival
# crossings + boundary sweep + deep mesh), not just the mild intense_storms.
#
# For each scenario: fixed default schedule A and a 2x-densified schedule B.
#   g_j          = net_reproduction_ratio_by_node * patch_densities  (per-slot J)
#   S_j          = |g_j - linear_interp(g_{j-1},g_{j+1} at tau_j)|   (surplus, from A only)
#   e(tau)       = |g_A - g_B|  interpolated to A's nodes            (actual error)
# Report Spearman(S, e), top-decile overlap, and where e concentrates (small-tau
# mass vs isolated spikes). High correlation => the one-solve indicator ranks the
# refinement targets the multi-solve reference would.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                                     export_all = TRUE, quiet = TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
ctrl <- control(ode_method = "rkck", ode_tol_rel = 1e-6, ode_tol_abs = 1e-6)

# scenario -> horizon chosen to exercise its hard dynamic while staying affordable
jobs <- list(
  extended_drought = 20,  # drought yr12-17 -> survival (rho->0) crossings
  dry_to_wet       = 20,   # aridity ramp -> leaf-shutdown boundary sweep
  long_horizon     = 30,   # deep evolved mesh
  whiplash         = 16    # repeated full-range excursions
)

densify <- function(t, k) { if (k <= 1) return(t); out <- numeric(0)
  for (i in seq_len(length(t)-1)) out <- c(out, seq(t[i], t[i+1], length.out=k+1)[-(k+1)])
  c(out, t[length(t)]) }

run_fixed <- function(mkpars, mkenv, sched) {
  scm <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl)
  scm$set_node_schedule_times(list(sched)); scm$run()
  sp <- scm$patch$species[[1]]
  list(J=sum(scm$offspring_production), tau=sp$node_times,
       g = sp$net_reproduction_ratio_by_node * sp$patch_densities)
}

# surplus per interior node: |g_j - linear interp of neighbours at tau_j|
surplus <- function(tau, g) {
  n <- length(tau); S <- numeric(n)
  for (j in 2:(n-1)) {
    w <- (tau[j]-tau[j-1])/(tau[j+1]-tau[j-1])
    S[j] <- abs(g[j] - ((1-w)*g[j-1] + w*g[j+1]))
  }
  S[1] <- S[2]; S[n] <- S[n-1]; S
}

cat(sprintf("%-18s %-5s %-6s %-8s %-9s %-9s %-9s\n",
            "scenario","nA","relAB","spearman","top10ov","errsmallt","errspike"))
res <- list()
for (nm in names(jobs)) {
  years <- jobs[[nm]]
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years*365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd-1))/365; tmax <- max(times)
  mkenv  <- function(){ e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  mkpars <- function(){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
    add_strategies(p, trait_matrix(0.0825,"lma"), birth_rate=1) }

  scm0 <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl); scm0$run()
  base <- scm0$patch$species[[1]]$node_times
  A <- run_fixed(mkpars, mkenv, base)
  B <- run_fixed(mkpars, mkenv, densify(base, 2))

  # actual per-slot error at A's nodes (from a common fine grid)
  grid <- seq(0, tmax, length.out=4000)
  gA <- approx(A$tau, A$g, grid, rule=2)$y
  gB <- approx(B$tau, B$g, grid, rule=2)$y
  e_grid <- abs(gA - gB)
  e_at_A <- approx(grid, e_grid, A$tau, rule=2)$y   # actual error near each A node
  S <- surplus(A$tau, A$g)                          # single-solve indicator

  sp <- suppressWarnings(cor(S, e_at_A, method="spearman"))
  k <- max(1, round(0.1*length(S)))
  topS <- order(S, decreasing=TRUE)[1:k]; topE <- order(e_at_A, decreasing=TRUE)[1:k]
  ov <- length(intersect(topS, topE))/k
  # where the actual error sits: mass fraction in first 20% of the lineage axis; and
  # spikiness (max/mean of e) as a survival-crossing tell
  half <- A$tau <= 0.2*tmax
  err_smallt <- sum(e_at_A[half])/sum(e_at_A)
  err_spike  <- max(e_at_A)/mean(e_at_A)
  cat(sprintf("%-18s %-5d %-6.3f %-8.3f %-9.2f %-9.3f %-9.1f\n",
              nm, length(A$tau), abs(A$J-B$J)/A$J, sp, ov, err_smallt, err_spike)); flush(stdout())
  res[[nm]] <- list(years=years, tau=A$tau, S=S, e=e_at_A, relAB=abs(A$J-B$J)/A$J,
                    spearman=sp, top10=ov, err_smallt=err_smallt, err_spike=err_spike)
}
saveRDS(res, file.path(outdir, "goal_placement_predict.rds"))
cat("ALLDONE\n")
