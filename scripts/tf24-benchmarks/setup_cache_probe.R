# P1 -- Resolve the setup-caching contradiction. A MEASUREMENT, no build.
#
# THE CONTRADICTION. Our own record disagrees with itself. The cost-structure
# round said the ~11-unit per-member setup is `u`-INDEPENDENT and therefore
# cacheable once per macro interval; the later characterisation charged it per
# `u`-change. The difference matters: mri_uptake pays 4 member sweeps per leg
# (1 anchor + 3 kutta3 slow stages), and each sweep re-runs the setup. If the
# setup is cacheable, all 4 share one setup and we save (4-1)/4 of it.
#
# WHAT THE SETUP IS. Per cohort, one member evaluation is
#   [A] allocation/geometry block in TF24_Strategy::net_mass_production_dt
#       (masses, the Q() root-mass distribution over layers, kmax, sapwood vol)
#   [B] Leaf::set_physiology  -- root hydraulic network (r_R_H_min, r_R_V,
#       r_R_V_sum, c_r_*), gravitational heads, the Arrhenius temperature block,
#       electron transport
#   [C] Leaf::find_root_collar_psi -- prepare_collar_solve + the argmax search
#       over collar potential (the objective evals)
#
# THE STRUCTURAL READING (read off the source before measuring, so the
# measurement can falsify it rather than be fitted to it):
#   - [A] depends on height/area_leaf (FROZEN for the leg by freeze_slow) and on
#     environment scalars (vpd/temp/ca/PPFD -- also frozen per leg). NOT on u.
#   - [B] takes psi_soil as an ARGUMENT but only *stores* it (psi_soil_ = psi_soil
#     plus a finiteness loop). Every expensive line -- the per-layer resistance
#     network, grav_head_z_, the peak_arrh_curve block -- is a function of
#     mass_root_prop / dz / temperature, none of which move with u.
#   - [C] is where u actually enters: prepare_collar_solve builds
#     psi_soil_inverted_ and root_vuln_integral_soil_ from psi_soil_, then the
#     search runs. This is NOT cacheable.
# So the structural prediction is: the earlier claim is right, [A]+[B] are
# u-independent, and the honest cacheable share is [A]+[B] / ([A]+[B]+[C]).
#
# WHAT THIS SCRIPT MEASURES (the falsifiable part):
#   1. SHARE  -- t(set_physiology) vs t(find_root_collar_psi), across a wet->dry
#      sweep, since the argmax cost is strongly state-dependent (shutdown
#      branches exit early and cost almost nothing).
#   2. SAFETY -- the memoised-vs-not A/B. Reusing one Leaf and overwriting only
#      psi_soil_ must give BIT-IDENTICAL uptake to a freshly set-up Leaf. If it
#      does not, the setup is not cacheable no matter what the timings say, and
#      P1 answers "no" regardless.
#   3. SPEEDUP -- wall-clock of the cached path vs the full path, which is the
#      number P2 gets to bank.
#
# Note [A] is not separately timeable from R (it lives inside the strategy), so
# the reported cacheable share is a LOWER BOUND: it counts [B] only.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant", export_all=TRUE, quiet=TRUE)})
cat("loaded\n"); flush(stdout())

# --- leaf physiology: same operating point as duptake_ift_gate.R --------------
vcmax_25 <- 100; jmax_25 <- vcmax_25*167; c <- 2.04; b <- 3; psi_crit <- 5
beta2 <- 1; curv_fact_elec_trans <- 0.7; a <- 0.3; curv_fact_colim <- 0.99
g1_TF24 <- 46.32995; vulnerability_curve_ncontrol <- 100
ci_niter <- 1e5; beta_R_H <- 3.4e3; beta_R_V <- 9.4e4
root_c <- 2.65; root_b <- 1.29; root_psi_crit <- root_b*(log(1/0.05))^(1/root_c)
theta_hv <- 0.000157; K_s <- 1; h <- 5
PPFD <- 900; atm_vpd <- 2; ca <- 40; atm_o2 <- 21; leaf_temp <- 25; atm_kpa <- 101.3
area_leaf <- 0.05; rho <- 608; a_bio <- 0.0245
sapwood_vol <- theta_hv*h; kmax <- K_s*theta_hv/h
NLAY <- 5; soil_depth <- seq(0.2, 1.0, length.out=NLAY); mrp <- rep(1, NLAY)

# Production tolerances, not the 1e-12 gate tolerances: the argmax cost scales
# with the tolerance, so measuring the share at 1e-12 would overstate [C] and
# flatter the "setup is negligible" answer. Use what the SCM actually runs.
GSS_tol_abs <- 1e-6; ci_abs_tol <- 1e-6

mkleaf <- function() Leaf(vcmax_25=vcmax_25, jmax_25=jmax_25, c=c, b=b, psi_crit=psi_crit,
  root_c=root_c, root_b=root_b, root_psi_crit=root_psi_crit, beta2=beta2, a=a,
  curv_fact_elec_trans=curv_fact_elec_trans, curv_fact_colim=curv_fact_colim,
  GSS_tol_abs=GSS_tol_abs, vulnerability_curve_ncontrol=vulnerability_curve_ncontrol,
  ci_abs_tol=ci_abs_tol, ci_niter=ci_niter, g1_TF24=g1_TF24, beta_R_H=beta_R_H, beta_R_V=beta_R_V)
setp <- function(l, ps) l$set_physiology(area_leaf=area_leaf, mass_root_prop=mrp, rho=rho,
  a_bio=a_bio, PPFD=PPFD, psi_soil=ps, soil_depth=soil_depth, leaf_specific_conductance_max=kmax,
  atm_vpd=atm_vpd, ca=ca, sapwood_volume_per_leaf_area=sapwood_vol, leaf_temp=leaf_temp,
  atm_o2_kpa=atm_o2, atm_kpa=atm_kpa)

# Soil states spanning the operating range, in psi magnitude (-MPa). The dry end
# is where the argmax gets cheap (early shutdown exits) and so where the setup
# share is WORST for our hypothesis -- include it deliberately (lesson #3: never
# average over the layers/regimes that would refute you).
# Ceiling: beyond ~psi 2 uniform this leaf configuration hits the known dry-limit
# root-bracket failure in find_root_psi (a model-side branch, unrelated to P1), so
# the sweep stops short of it and reaches the dry end via the graded profile,
# where deep layers stay wet enough to keep the solve feasible.
states <- list(
  wet    = rep(0.05, NLAY),
  mid    = rep(0.8,  NLAY),
  dry    = rep(1.6,  NLAY),
  graded = seq(0.1, 1.9, length.out = NLAY)
)

bench <- function(f, min_time = 0.30) {
  f(); n <- 1L                       # warm up (spline/branch state)
  repeat {
    t0 <- proc.time()[["elapsed"]]
    for (i in seq_len(n)) f()
    dt <- proc.time()[["elapsed"]] - t0
    if (dt >= min_time) return(dt / n)
    n <- n * 2L
  }
}

cat(sprintf("%-8s %12s %12s %12s %10s %10s\n",
            "state", "setup_us", "solve_us", "total_us", "setup_%", "cached_x"))
rows <- list()
for (nm in names(states)) {
  ps <- states[[nm]]

  # (1) share. Time set_physiology alone, and the solve alone on an already
  # set-up leaf; total is the full uncached member evaluation.
  ls <- mkleaf(); setp(ls, ps)
  t_setup <- bench(function() setp(ls, ps))
  lv <- mkleaf(); setp(lv, ps)
  t_solve <- bench(function() lv$find_root_collar_psi())
  # The UNCACHED member evaluation as production actually runs it: the Leaf object
  # is a long-lived member of the Strategy, so construction (splines, the 100-point
  # vulnerability curves -- ~750us, 20x everything else) is NOT per-sweep and must
  # be excluded. Per sweep production pays set_physiology + find_root_collar_psi.
  lu <- mkleaf(); setp(lu, ps)
  t_full  <- bench(function() { setp(lu, ps); lu$find_root_collar_psi() })

  # (2) safety: cached path == fresh path, bit for bit. The cached path reuses a
  # leaf set up at a DIFFERENT soil state and overwrites only psi_soil_.
  lc <- mkleaf(); setp(lc, states$wet)   # deliberately the wrong state
  lc$psi_soil_ <- ps
  lc$find_root_collar_psi()
  lf <- mkleaf(); setp(lf, ps); lf$find_root_collar_psi()
  ident <- identical(lc$soil_consumption_, lf$soil_consumption_) &&
           identical(lc$root_collar_psi_,  lf$root_collar_psi_)

  # (3) speedup available to a cached member loop.
  lk <- mkleaf(); setp(lk, ps)
  t_cached <- bench(function() { lk$psi_soil_ <- ps; lk$find_root_collar_psi() })

  rows[[nm]] <- data.frame(state=nm, setup_us=t_setup*1e6, solve_us=t_solve*1e6,
                           total_us=t_full*1e6, cached_us=t_cached*1e6,
                           setup_share=t_setup/(t_setup+t_solve),
                           cached_speedup=t_full/t_cached, identical=ident)
  cat(sprintf("%-8s %12.1f %12.1f %12.1f %9.1f%% %9.2fx  bitident=%s\n",
              nm, t_setup*1e6, t_solve*1e6, t_full*1e6,
              100*t_setup/(t_setup+t_solve), t_full/t_cached, ident))
  flush(stdout())
}

res <- do.call(rbind, rows)
dir.create("scripts/tf24-benchmarks/results", showWarnings=FALSE, recursive=TRUE)
saveRDS(res, "scripts/tf24-benchmarks/results/setup_cache_probe.rds")

cat("\n--- verdict inputs ---\n")
cat(sprintf("setup share of a member sweep: %.1f%% - %.1f%% (median %.1f%%)\n",
            100*min(res$setup_share), 100*max(res$setup_share), 100*median(res$setup_share)))
cat(sprintf("cached-path speedup:           %.2fx - %.2fx (median %.2fx)\n",
            min(res$cached_speedup), max(res$cached_speedup), median(res$cached_speedup)))
cat(sprintf("cached == fresh, bit for bit:  %s\n",
            if (all(res$identical)) "YES (all states)" else "NO -- NOT CACHEABLE"))
cat("ALLDONE\n")
