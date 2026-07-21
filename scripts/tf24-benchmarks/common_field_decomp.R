# T3 (v2 Oracle response, claim 3) — now the DECISIVE test (T5a killed the
# granularity story; the residual 9c non-convergence is either field-shift or
# survivor-flips). Decompose the mesh N->2N J-movement on a COMMON field:
#   J_NN     = N members on N's frozen field         (run_mutant, sanity ~ J_N)
#   J_2NonN  = 2N members on N's frozen field        (run_mutant with 2N schedule)
#   J_2Nsc   = 2N members self-consistent            (normal run, 2N feeds back)
# Two-term split (sums exactly to J_2Nsc - J_NN):
#   quadrature = J_2NonN - J_NN     (placement/quadrature at fixed field; protocol)
#   fieldshift = J_2Nsc  - J_2NonN  (kappa-amplified feedback field change; protocol)
# Survivor-flips show up WITHIN whichever term is a localized spike near dying
# members (rho->0) rather than diffuse -> that part is intrinsic (item B).
# run_mutant uses make_node_schedule(p), which reads p$node_schedule_times, pinned
# to the resident's frozen field. T5a showed max weight fraction ~1.6%, so the
# frozen-field probe error (O(weight fraction), 9a) is small here -> trustworthy.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                                     export_all = TRUE, quiet = TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
CACHE <- control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6, save_RK45_cache=TRUE)
PLAIN <- control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6)
jobs <- list(intense_storms = 12, whiplash = 16)

densify <- function(base, mult) {
  if (mult == 1) return(base)
  d <- numeric(0)
  for (i in seq_len(length(base)-1)) d <- c(d, seq(base[i], base[i+1], length.out=mult+1)[-(mult+1)])
  sort(unique(c(d, base[length(base)])))
}
g_of <- function(scm) { sp <- scm$patch$species[[1]]
  list(tau = sp$node_times, g = sp$net_reproduction_ratio_by_node * sp$patch_densities) }
# localized-vs-diffuse: fraction of the |g| difference carried by the top 3 tau bins
spikiness <- function(gA, gB) {
  tm <- max(c(gA$tau, gB$tau)); grid <- seq(0, tm, length.out = 4000)
  a <- approx(gA$tau, gA$g, grid, rule=2)$y; b <- approx(gB$tau, gB$g, grid, rule=2)$y
  d <- abs(a - b); if (sum(d) <= 0) return(c(top3=NA, atsmall=NA))
  dr <- sort(d, decreasing=TRUE)
  c(top3 = sum(head(dr,3))/sum(d),                       # 3/4000 bins: >~0.5 => spike
    atsmall = sum(d[grid <= 0.1*tm])/sum(d))              # mass at small tau_ins
}

for (nm in names(jobs)) {
  years <- jobs[[nm]]
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years*365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd-1))/365; tmax <- max(times)
  mkenv  <- function(){ e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  mkp <- function(sched=NULL){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
    p <- add_strategies(p, trait_matrix(0.0825,"lma"), birth_rate=1)
    if (!is.null(sched)) p$node_schedule_times <- list(sort(unique(sched))); p }
  # default schedule N (from a plain run)
  s0 <- SCM("TF24","TF24_Env")(mkp(), mkenv(), PLAIN); s0$run()
  baseN <- s0$patch$species[[1]]$node_times

  # fresh resident (cache) per mutant probe to keep step_history intact
  resident <- function() { scm <- SCM("TF24","TF24_Env")(mkp(baseN), mkenv(), CACHE); scm$run(); scm }
  rN <- resident(); J_N <- sum(rN$offspring_production)
  # run_mutant pins insertion to the resident's frozen ode-step grid, so a mutant
  # schedule must land ON those step times. Snap both schedules to the nearest
  # resident ode time (5000+ available -> negligible snap error).
  ode_t <- rN$ode_times
  snap <- function(sched) sort(unique(vapply(sched, function(t) ode_t[which.min(abs(ode_t - t))], numeric(1))))
  baseN_s <- snap(baseN); sched2N <- snap(densify(baseN, 2))
  cat(sprintf("\n== %s (%dyr) N=%d 2N=%d (snapped to %d ode times) ==\n",
              nm, years, length(baseN_s), length(sched2N), length(ode_t))); flush(stdout())
  # N on N field
  rNN <- resident(); rNN$run_mutant(mkp(baseN_s)); J_NN <- sum(rNN$offspring_production); gNN <- g_of(rNN)
  # 2N on N field
  r2NonN <- resident(); r2NonN$run_mutant(mkp(sched2N)); J_2NonN <- sum(r2NonN$offspring_production); g2NonN <- g_of(r2NonN)
  # 2N self-consistent
  s2 <- SCM("TF24","TF24_Env")(mkp(sched2N), mkenv(), PLAIN); s2$run(); J_2Nsc <- sum(s2$offspring_production); g2sc <- g_of(s2)

  quad <- J_2NonN - J_NN; fieldshift <- J_2Nsc - J_2NonN; total <- J_2Nsc - J_NN
  sp_fs <- spikiness(g2sc, g2NonN)     # field-shift geometry (2Nsc vs 2NonN)
  sp_q  <- spikiness(g2NonN, gNN)      # quadrature geometry  (2NonN vs NN)
  cat(sprintf("J_N=%.4e  J_NN(sanity)=%.4e relgap=%.2e\n", J_N, J_NN, abs(J_NN-J_N)/abs(J_N)))
  cat(sprintf("J_2NonN=%.4e  J_2Nsc=%.4e\n", J_2NonN, J_2Nsc))
  cat(sprintf("DECOMP of dJ=%.4e : quadrature=%.4e (%.0f%%)  fieldshift=%.4e (%.0f%%)\n",
              total, quad, 100*quad/total, fieldshift, 100*fieldshift/total))
  cat(sprintf("  quadrature geometry: top3-bin frac=%.2f  small-tau frac=%.2f\n", sp_q["top3"], sp_q["atsmall"]))
  cat(sprintf("  fieldshift geometry: top3-bin frac=%.2f  small-tau frac=%.2f\n", sp_fs["top3"], sp_fs["atsmall"]))
  cat(sprintf("  => %s dominates; %s\n",
              ifelse(abs(fieldshift)>abs(quad),"FIELD-SHIFT (feedback)","QUADRATURE (placement)"),
              ifelse(max(sp_fs["top3"],sp_q["top3"],na.rm=TRUE)>0.5,"SPIKE present (survivor-flip/intrinsic)","diffuse (protocol)")))
  flush(stdout())
  saveRDS(list(J_N=J_N,J_NN=J_NN,J_2NonN=J_2NonN,J_2Nsc=J_2Nsc,quad=quad,fieldshift=fieldshift,
               gNN=gNN,g2NonN=g2NonN,g2sc=g2sc,sp_fs=sp_fs,sp_q=sp_q),
          file.path(outdir, paste0("common_field_decomp_", nm, ".rds")))
}
cat("ALLDONE\n")
