suppressMessages(pkgload::load_all("plant", quiet=TRUE)); options(width=115)
theta_h<-0.000157; h<-10; K_s<-1
L <- Leaf(vcmax_25=100, jmax_25=100*167, c=2.04, b=3, psi_crit=5, root_c=2.65, root_b=1.29,
  root_psi_crit=1.29*(log(1/0.05))^(1/2.65), beta2=1, a=0.3, curv_fact_elec_trans=0.7,
  curv_fact_colim=0.99, GSS_tol_abs=1e-6, vulnerability_curve_ncontrol=100, ci_abs_tol=1e-6,
  ci_niter=1000, g1_TF24=46.32995, beta_R_H=3.4e3, beta_R_V=9.4e4)
setphys<-function(ps) L$set_physiology(area_leaf=0.05, mass_root_prop=1, rho=608, a_bio=0.0245,
  PPFD=900, psi_soil=ps, soil_depth=1, leaf_specific_conductance_max=K_s*theta_h/h, atm_vpd=2, ca=40,
  sapwood_volume_per_leaf_area=theta_h*h, leaf_temp=25, atm_o2_kpa=21, atm_kpa=101.3)
timeit<-function(f,reps){f();t<-Sys.time();for(i in seq_len(reps))f();as.numeric(Sys.time()-t,units="secs")*1e6/reps}
setphys(2.0); L$find_root_collar_psi(); q0<- -L$root_collar_psi_
t_set<-timeit(function() setphys(2.0), 5000)
t_setopt<-timeit(function(){setphys(2.0);L$find_root_collar_psi()},2000)
t_setev<-timeit(function(){setphys(2.0);L$evaluate_root_collar_psi(q0)},2000)
cat(sprintf("set_physiology alone = %.2f us ; +optimise = %.2f ; +evaluate = %.2f\n",t_set,t_setopt,t_setev))
cat(sprintf("=> prepare+profit(optimise) = %.2f ; prepare+profit(evaluate) = %.2f ; GSS-only extra = %.2f us\n",
    t_setopt-t_set, t_setev-t_set, t_setopt-t_setev))
# E2: is the per-cohort uptake smooth across cohort HEIGHT so m<<N collocation works?
# vary height, at fixed psi_soil; record optimised profit and opt operating point.
cat("\nE2 probe: operating point & profit vs cohort height (fixed psi_soil=2):\n")
setphys<-function(ps,hh) L$set_physiology(area_leaf=0.05, mass_root_prop=1, rho=608, a_bio=0.0245,
  PPFD=900, psi_soil=ps, soil_depth=1, leaf_specific_conductance_max=K_s*theta_h/hh, atm_vpd=2, ca=40,
  sapwood_volume_per_leaf_area=theta_h*hh, leaf_temp=25, atm_o2_kpa=21, atm_kpa=101.3)
cat(sprintf("  %6s %10s %10s\n","height","q_opt","profit"))
for(hh in c(0.5,1,2,4,7,10,14)){ setphys(2.0,hh); L$find_root_collar_psi()
  cat(sprintf("  %6.1f %10.4f %10.4f\n", hh, -L$root_collar_psi_, L$profit_)) }
