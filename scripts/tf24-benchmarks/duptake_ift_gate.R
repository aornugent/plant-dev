# T6 Slice 2 OFFLINE GATE (pure R, exposed Leaf API, zero new C++).
#
# Question: can the per-leaf water uptake per layer c_i be cheaply refreshed as
# soil water moves, using an ANALYTIC slope that captures the operating-point
# response WITHOUT re-solving the leaf optimum -- and is that slope correct at the
# DRY LIMIT (where the ancestors' refresh died)?
#
# The uptake c_i depends on soil water through (a) the explicit soil potential in
# each layer and (b) the collar operating point P*, which itself moves with soil
# water. The operating point solves g(P*, psi_soil) := dprofit_droot_collar_psi = 0.
# By the implicit function theorem, dP*/dpsi_soil_k = -(dg/dpsi_soil_k)/(dg/dP*),
# using ONLY the analytic gradient g (no re-solve, no FD-through-the-search). Then
#   dc_i/dpsi_soil_k = [dc_i/dpsi_soil_k]_{P* fixed}  +  (dc_i/dP*)*(dP*/dpsi_soil_k).
#
# GATE: reconstruct dc_i/dpsi_soil_k this analytic-IFT way and compare to the true
# Jacobian obtained by FINITE-DIFFERENCING A FULL OPERATING-POINT RE-SOLVE
# (find_root_collar_psi at each perturbed soil). The re-solve reference includes
# the real operating-point motion; if the IFT reconstruction matches it (esp. in
# the dry tercile), the cheap analytic refresh is sound -> build the C++ da/du for
# Slice 3. If it disagrees near the dry limit -> STOP (the refresh is wrong where
# it matters).
#
# Validation is in psi_soil (potential-magnitude) space: the retention chain
# dpsi/dtheta is a known analytic diagonal factor (dpsi/dtheta = -n_psi*psi/theta)
# common to both sides, so isolating the leaf-coupling mechanism here is the clean
# test. Newton is unnecessary for the reference: a tight golden-section (GSS_tol_abs
# 1e-10) already gives an un-quantized operating point.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant", export_all=TRUE, quiet=TRUE)})
cat("loaded\n"); flush(stdout())
outdir <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"

# --- leaf physiology (from test-leaf.r), tight tolerances for a clean reference ---
vcmax_25 <- 100; jmax_25 <- vcmax_25*167; c <- 2.04; b <- 3; psi_crit <- 5
beta2 <- 1; curv_fact_elec_trans <- 0.7; a <- 0.3; curv_fact_colim <- 0.99
g1_TF24 <- 46.32995; GSS_tol_abs <- 1e-12; vulnerability_curve_ncontrol <- 100
ci_abs_tol <- 1e-12; ci_niter <- 1e5; beta_R_H <- 3.4e3; beta_R_V <- 9.4e4
root_c <- 2.65; root_b <- 1.29; root_psi_crit <- root_b*(log(1/0.05))^(1/root_c)
theta_hv <- 0.000157; K_s <- 1; h <- 5
PPFD <- 900; atm_vpd <- 2; ca <- 40; atm_o2 <- 21; leaf_temp <- 25; atm_kpa <- 101.3
area_leaf <- 0.05; rho <- 608; a_bio <- 0.0245
sapwood_vol <- theta_hv*h; kmax <- K_s*theta_hv/h
NLAY <- 5; soil_depth <- seq(0.2, 1.0, length.out=NLAY); mrp <- rep(1, NLAY)

mkleaf <- function() Leaf(vcmax_25=vcmax_25, jmax_25=jmax_25, c=c, b=b, psi_crit=psi_crit,
  root_c=root_c, root_b=root_b, root_psi_crit=root_psi_crit, beta2=beta2, a=a,
  curv_fact_elec_trans=curv_fact_elec_trans, curv_fact_colim=curv_fact_colim,
  GSS_tol_abs=GSS_tol_abs, vulnerability_curve_ncontrol=vulnerability_curve_ncontrol,
  ci_abs_tol=ci_abs_tol, ci_niter=ci_niter, g1_TF24=g1_TF24, beta_R_H=beta_R_H, beta_R_V=beta_R_V)
setp <- function(l, ps) l$set_physiology(area_leaf=area_leaf, mass_root_prop=mrp, rho=rho,
  a_bio=a_bio, PPFD=PPFD, psi_soil=ps, soil_depth=soil_depth, leaf_specific_conductance_max=kmax,
  atm_vpd=atm_vpd, ca=ca, sapwood_volume_per_leaf_area=sapwood_vol, leaf_temp=leaf_temp,
  atm_o2_kpa=atm_o2, atm_kpa=atm_kpa)

# uptake vector c_i and operating point Pstar at a soil state, op point RE-SOLVED
uptake_resolve <- function(ps){ l <- mkleaf(); setp(l, ps); l$find_root_collar_psi()
  list(c=l$soil_consumption_, Pstar=-l$root_collar_psi_) }
solve_base <- function(ps){ l <- mkleaf(); setp(l, ps); l$find_root_collar_psi()
  list(c0=l$soil_consumption_, Pstar=-l$root_collar_psi_,
       shutdown = (l$E_up_ == 0) || all(abs(l$soil_consumption_) < 1e-30)) }

HREL <- 1e-4    # near-optimal central-difference step for solver tol 1e-12 (h_opt ~ tol^(1/3))
# ---- one gate evaluation at soil state ps ----
gate_state <- function(ps){
  base <- solve_base(ps); if (base$shutdown) return(NULL)
  Pstar <- base$Pstar
  hp <- HREL*max(1, abs(Pstar))                      # op-point perturbation
  # dg/dP* at fixed soil (analytic gradient g = dprofit_droot_collar_psi)
  lb <- mkleaf(); setp(lb, ps); lb$find_root_collar_psi()   # sets psi_soil_inverted_ for ps
  # interior-stationarity residual: ~0 at an interior optimum, != 0 when the
  # operating point is pinned to a feasible-interval boundary (active constraint,
  # where IFT on dprofit==0 does NOT hold). Scaled by the local curvature*psi.
  g_at_Pstar <- lb$dprofit_droot_collar_psi(Pstar)
  gP <- (lb$dprofit_droot_collar_psi(Pstar+hp) - lb$dprofit_droot_collar_psi(Pstar-hp))/(2*hp)
  if (!is.finite(gP) || abs(gP) < 1e-30) return(NULL)
  # dc_i/dP* at fixed soil, via evaluate_root_collar_psi (closed-form, holds op point)
  le <- mkleaf(); setp(le, ps); le$evaluate_root_collar_psi(Pstar+hp); cP_p <- le$soil_consumption_
  le <- mkleaf(); setp(le, ps); le$evaluate_root_collar_psi(Pstar-hp); cP_m <- le$soil_consumption_
  dc_dP <- (cP_p - cP_m)/(2*hp)                        # length NLAY

  D_an <- matrix(0, NLAY, NLAY); D_ref <- matrix(0, NLAY, NLAY)
  dP_ift <- dP_ref <- rep(NA, NLAY)                    # operating-point response, IFT vs re-solve
  for (k in seq_len(NLAY)) {
    hk <- HREL*max(1, abs(ps[k]))
    psp <- ps; psp[k] <- ps[k]+hk; psm <- ps; psm[k] <- ps[k]-hk
    # --- analytic-IFT column k ---
    lp <- mkleaf(); setp(lp, psp); lp$evaluate_root_collar_psi(Pstar); cexp_p <- lp$soil_consumption_
    gp  <- lp$dprofit_droot_collar_psi(Pstar)
    lm <- mkleaf(); setp(lm, psm); lm$evaluate_root_collar_psi(Pstar); cexp_m <- lm$soil_consumption_
    gm  <- lm$dprofit_droot_collar_psi(Pstar)
    explicit_col <- (cexp_p - cexp_m)/(2*hk)            # nonzero ~ only row k
    g_k <- (gp - gm)/(2*hk)                             # dg/dpsi_soil_k (op fixed)
    dPstar_dpsik <- -g_k/gP                             # IFT prediction of op-point response
    D_an[,k] <- explicit_col + dc_dP*dPstar_dpsik
    dP_ift[k] <- dPstar_dpsik
    # --- reference column k: full operating-point re-solve ---
    rp <- uptake_resolve(psp); rm <- uptake_resolve(psm)
    D_ref[,k] <- (rp$c - rm$c)/(2*hk)
    dP_ref[k] <- (rp$Pstar - rm$Pstar)/(2*hk)           # true op-point response
  }
  scale <- max(abs(D_ref)); if (scale <= 0) return(NULL)
  dPscale <- max(abs(dP_ref))
  # boundary indicator: |g(Pstar)| relative to |gP|*Pstar (a dimensionless measure
  # of how far the stationarity condition is from satisfied at the operating point)
  interior_resid <- abs(g_at_Pstar) / max(1e-30, abs(gP)*max(1,abs(Pstar)))
  list(relmax = max(abs(D_an - D_ref))/scale,
       relfro = sqrt(sum((D_an-D_ref)^2))/sqrt(sum(D_ref^2)),
       # the load-bearing identity in isolation: IFT op-point response vs re-solve
       relP   = if (dPscale > 0) max(abs(dP_ift - dP_ref))/dPscale else NA,
       resid  = interior_resid,
       driest = max(ps))                                # larger magnitude = drier
}

# ---- soil states spanning wet -> dry (driest layer approaches psi_crit) ----
set.seed(1)   # (Math.random-free; seed fixed for reproducibility)
states <- list()
driest_targets <- seq(0.2, 4.6, length.out=15)         # driest-layer magnitude, below psi_crit=5
for (d in driest_targets) for (rep in 1:3) {
  ps <- sort(runif(NLAY, 0.1, d))                      # increasing magnitude with depth-ish
  ps[NLAY] <- d                                        # pin the driest layer
  states[[length(states)+1]] <- ps
}
cat(sprintf("gating %d soil states across driest-layer magnitude [%.2f, %.2f]\n",
            length(states), min(driest_targets), max(driest_targets))); flush(stdout())

res <- Filter(Negate(is.null), lapply(states, gate_state))
relmax <- sapply(res, `[[`, "relmax"); relfro <- sapply(res, `[[`, "relfro")
relP   <- sapply(res, `[[`, "relP");   driest <- sapply(res, `[[`, "driest")
resid  <- sapply(res, `[[`, "resid")
q <- quantile(driest, c(1/3, 2/3))
wet <- driest <= q[1]; mid <- driest > q[1] & driest <= q[2]; dry <- driest > q[2]
ssum <- function(v) sprintf("med=%.2e p90=%.2e max=%.2e", median(v,na.rm=TRUE), quantile(v,.9,na.rm=TRUE), max(v,na.rm=TRUE))
cat(sprintf("\n== analytic-IFT vs full-resolve FD  (%d non-shutdown states, HREL=%.0e, tol 1e-12) ==\n", length(res), HREL))
cat(sprintf("  IFT op-point response dP*/dpsi  ALL: %s\n", ssum(relP)))
cat(sprintf("  IFT op-point response dP*/dpsi  DRY: %s\n", ssum(relP[dry])))
cat(sprintf("  full Jacobian rel(max-entry)    ALL: %s\n", ssum(relmax)))
cat(sprintf("  full Jacobian rel(frobenius)    ALL: %s\n", ssum(relfro)))
cat(sprintf("  full Jacobian rel(max-entry)    DRY tercile (driest mag > %.2f): %s\n", q[2], ssum(relmax[dry])))
cat(sprintf("  full Jacobian rel(max-entry)    WET tercile (driest mag <= %.2f): %s\n", q[1], ssum(relmax[wet])))
# mechanism check: does the error track the interior-stationarity residual
# (i.e. is the operating point boundary-pinned where the reconstruction fails)?
interior <- resid < 1e-3; boundary <- !interior
cat(sprintf("\n  boundary-pinned states (interior residual >= 1e-3): %d / %d\n", sum(boundary), length(res)))
cat(sprintf("  full Jacobian rel(max) INTERIOR-optimum states: %s\n", ssum(relmax[interior])))
cat(sprintf("  full Jacobian rel(max) BOUNDARY-pinned states:  %s\n", ssum(relmax[boundary])))
cat(sprintf("  spearman(error, interior residual) = %.3f\n", suppressWarnings(cor(relmax, resid, method="spearman"))))
saveRDS(list(relmax=relmax, relfro=relfro, relP=relP, resid=resid, driest=driest), file.path(outdir, "duptake_ift_gate.rds"))
cat("ALLDONE\n")
