#!/usr/bin/env Rscript
# E1 (Oracle go/no-go): continuation economics of the inner per-cohort solve.
# The inner solve is a fixed-iteration golden-section search (find_root_collar_psi) that
# maximises carbon profit over the collar potential; it is NOT Newton-warm-startable by
# design (fixed iterations -> smooth argmax, which the demographic gradient needs).
# BUT plant exposes evaluate_root_collar_psi(q) [evaluate at a point, ~1 profit eval] and
# the EXACT gradient dprofit_droot_collar_psi(q) [IFT]. TF24f already tracks q as a state.
# E1 asks: (A) how much cheaper is evaluate-at-point than optimise? (B) as psi_soil moves a
# realistic micro-step, does the optimum drift little enough that a warm continuation from
# the previous optimum re-converges in ~1 gradient/Newton step (cost ~ evaluate), including
# at the near-singular dry end? Kill: warm cost > ~1/3 cold across the range.
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)); options(width=115)

# a representative leaf (from test-leaf.r), height 10 m
theta_h<-0.000157; h<-10; K_s<-1
L <- Leaf(vcmax_25=100, jmax_25=100*167, c=2.04, b=3, psi_crit=5, root_c=2.65, root_b=1.29,
  root_psi_crit=1.29*(log(1/0.05))^(1/2.65), beta2=1, a=0.3, curv_fact_elec_trans=0.7,
  curv_fact_colim=0.99, GSS_tol_abs=1e-6, vulnerability_curve_ncontrol=100, ci_abs_tol=1e-6,
  ci_niter=1000, g1_TF24=46.32995, beta_R_H=3.4e3, beta_R_V=9.4e4)
setphys<-function(psi_soil) L$set_physiology(area_leaf=0.05, mass_root_prop=1, rho=608, a_bio=0.0245,
  PPFD=900, psi_soil=psi_soil, soil_depth=1, leaf_specific_conductance_max=K_s*theta_h/h,
  atm_vpd=2, ca=40, sapwood_volume_per_leaf_area=theta_h*h, leaf_temp=25, atm_o2_kpa=21, atm_kpa=101.3)

opt_at<-function(ps){ setphys(ps); L$find_root_collar_psi(); c(q=-L$root_collar_psi_, profit=L$profit_) }
# evaluate profit + exact gradient at a candidate collar potential q (>0 magnitude), given ps
grad_at<-function(ps,q){ setphys(ps); pr<-L$evaluate_root_collar_psi(q); c(profit=pr, dpr=L$dprofit_droot_collar_psi(q)) }

timeit<-function(f,reps){ f(); t<-Sys.time(); for(i in seq_len(reps)) f(); as.numeric(Sys.time()-t,units="secs")*1e6/reps } # us

## (A) cost: optimise (GSS) vs evaluate-at-point vs evaluate+gradient
ps0<-2.0; o<-opt_at(ps0); q0<-o["q"]
t_opt <- timeit(function(){ setphys(ps0); L$find_root_collar_psi() }, 2000)
t_ev  <- timeit(function(){ setphys(ps0); L$evaluate_root_collar_psi(q0) }, 2000)
t_evg <- timeit(function(){ setphys(ps0); L$evaluate_root_collar_psi(q0); L$dprofit_droot_collar_psi(q0) }, 2000)
cat(sprintf("(A) per-leaf cost (us):  optimise(GSS)=%.2f   evaluate=%.2f   evaluate+grad=%.2f   speedup opt/eval=%.1fx\n\n",
    t_opt, t_ev, t_evg, t_opt/t_ev))

## (B) optimum drift + warm re-convergence over a realistic dry-down, incl. near-singular end
# psi_soil sweeps wet->dry; micro-step in psi_soil chosen ~ what a soil sub-step produces.
cat("(B) warm continuation from previous optimum vs cold optimise, along a dry-down:\n")
cat(sprintf("    %8s %8s | %10s %10s | %10s %8s\n","psi_soil","dpsi","q*(cold)","q(warm1)","|q*-warm|","nNewton"))
newton_from<-function(ps, qseed, tol=1e-6, maxit=8){        # warm Newton on dprofit=0 from qseed
  q<-qseed; eps<-1e-4
  for(it in 1:maxit){ g<-grad_at(ps,q)["dpr"]
    if(abs(g)<tol) return(c(q=q, nit=it-1))
    g2<-(grad_at(ps,q+eps)["dpr"]-g)/eps                    # FD 2nd deriv (2 evals)
    step<- -g/g2; if(!is.finite(step)) break
    q<-max(1e-4, q+max(-1,min(1,step))) }                  # clamp step for robustness
  c(q=q, nit=maxit) }
psis<-seq(0.5, 4.5, by=0.25); qprev<-opt_at(psis[1])["q"]
for(i in 2:length(psis)){ ps<-psis[i]; dpsi<-ps-psis[i-1]
  qcold<-opt_at(ps)["q"]                                    # truth (cold GSS)
  w<-newton_from(ps, qprev); qwarm<-w["q"]
  cat(sprintf("    %8.2f %8.2f | %10.4f %10.4f | %10.2e %8d\n", ps, dpsi, qcold, qwarm, abs(qcold-qwarm), w["nit"]))
  qprev<-qcold }
cat("\nIf evaluate << optimise (A) and warm Newton needs ~1-2 steps with tiny |q*-warm| across the\n")
cat("range incl. the dry end (B), continuation is validated: build the multirate on tracked-q (TF24f-style).\n")
