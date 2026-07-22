# T6 Slice 3a RE-GATE: the ANALYTIC C++ per-leaf uptake Jacobian
# (Leaf::compute_duptake_dpsi_soil, two-branch: interior IFT + boundary continuity IFT)
# vs a finite difference of a full operating-point re-solve. Unlike the Slice-2 gate
# (FD-vs-FD), the analytic side is now the shipped C++ method, so this validates the
# actual implementation across wet AND dry (boundary-pinned) states.
#
# Convention: compute_duptake_dpsi_soil returns d c_i / d psi_soil_inverted_k (signed
# potential). set_physiology takes psi_soil as a positive magnitude m_k = -psi_inverted_k,
# so the re-solve FD in magnitude space gives d c_i/d m_k = -d c_i/d psi_inverted_k. We
# therefore compare D_analytic (inverted) against -D_ref_mag.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant", export_all=TRUE, quiet=TRUE)})
cat("loaded\n"); flush(stdout())
outdir <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"

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
uptake_resolve <- function(ps){ l <- mkleaf(); setp(l, ps); l$find_root_collar_psi(); l$soil_consumption_ }

HREL <- 1e-4
gate_state <- function(ps){
  l <- mkleaf(); setp(l, ps); l$find_root_collar_psi()
  if (l$E_up_ == 0 || all(abs(l$soil_consumption_) < 1e-30)) return(NULL)  # shutdown
  l$compute_duptake_dpsi_soil()
  D_an <- matrix(l$duptake_dpsi_soil_, NLAY, NLAY, byrow=TRUE)  # d c_i / d psi_inverted_k
  D_ref <- matrix(0, NLAY, NLAY); c0 <- l$soil_consumption_
  kink <- FALSE
  for (k in seq_len(NLAY)) {
    hk <- HREL*max(1, abs(ps[k]))
    psp <- ps; psp[k] <- ps[k]+hk; psm <- ps; psm[k] <- ps[k]-hk
    cp <- uptake_resolve(psp); cm <- uptake_resolve(psm)
    D_ref[,k] <- -(cp - cm)/(2*hk)                             # central (sign: mag->inverted)
    # kink detector: forward vs backward one-sided slopes disagreeing => derivative
    # discontinuous across this perturbation (an interior<->boundary transition)
    dfwd <- -(cp - c0)/hk; dbwd <- -(c0 - cm)/hk
    sc <- max(abs(c(dfwd, dbwd))); if (sc > 0 && max(abs(dfwd-dbwd))/sc > 1e-2) kink <- TRUE
  }
  scale <- max(abs(D_ref)); if (scale <= 0) return(NULL)
  Ppos <- -l$root_collar_psi_
  resid <- abs(l$dprofit_droot_collar_psi(Ppos))   # ~0 interior, !=0 boundary-pinned
  list(relmax = max(abs(D_an - D_ref))/scale,
       relfro = sqrt(sum((D_an-D_ref)^2))/sqrt(sum(D_ref^2)),
       kink = kink, driest = max(ps), wettest = min(ps), resid = resid, Ppos = Ppos, ps = ps)
}

set.seed(1)
states <- list()
for (d in seq(0.2, 4.6, length.out=15)) for (rep in 1:3) {
  ps <- sort(runif(NLAY, 0.1, d)); ps[NLAY] <- d
  states[[length(states)+1]] <- ps
}
cat(sprintf("re-gating %d soil states, driest-layer magnitude [0.2, 4.6] (psi_crit=%.1f)\n",
            length(states), psi_crit)); flush(stdout())
res <- Filter(Negate(is.null), lapply(states, gate_state))
relmax <- sapply(res, `[[`, "relmax"); relfro <- sapply(res, `[[`, "relfro"); driest <- sapply(res, `[[`, "driest")
kink <- sapply(res, `[[`, "kink")
q <- quantile(driest, c(1/3, 2/3)); wet <- driest <= q[1]; dry <- driest > q[2]
ssum <- function(v) sprintf("med=%.2e p90=%.2e max=%.2e", median(v), quantile(v,.9), max(v))
cat(sprintf("\n== ANALYTIC C++ da/du vs full-resolve FD  (%d non-shutdown states) ==\n", length(res)))
cat(sprintf("  rel(max-entry) ALL: %s\n", ssum(relmax)))
cat(sprintf("  rel(frobenius) ALL: %s\n", ssum(relfro)))
cat(sprintf("  rel(max-entry) DRY tercile (driest mag > %.2f): %s\n", q[2], ssum(relmax[dry])))
cat(sprintf("  rel(max-entry) WET tercile (driest mag <= %.2f): %s\n", q[1], ssum(relmax[wet])))
cat(sprintf("\n  KINK states (interior<->boundary transition straddled by FD): %d / %d\n", sum(kink), length(res)))
cat(sprintf("  rel(max-entry) SMOOTH states only: %s\n", ssum(relmax[!kink])))
cat(sprintf("  rel(max-entry) KINK states only:   %s\n", ssum(relmax[kink])))
resid <- sapply(res, `[[`, "resid"); Ppos <- sapply(res, `[[`, "Ppos"); wettest <- sapply(res, `[[`, "wettest")
cat("\n  worst 8 states (relmax, driest, wettest, Ppos, stationarity-resid, kink):\n")
ord <- order(-relmax)[1:min(8,length(res))]
for (j in ord) cat(sprintf("    rel=%.2e  driest=%.2f wettest=%.2f  Ppos=%.3f  resid=%.2e  kink=%s\n",
                           relmax[j], driest[j], wettest[j], Ppos[j], resid[j], res[[j]]$kink))
saveRDS(list(relmax=relmax, relfro=relfro, driest=driest), file.path(outdir, "duptake_analytic_regate.rds"))
cat("ALLDONE\n")
