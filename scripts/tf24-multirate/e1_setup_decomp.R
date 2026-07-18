suppressMessages(pkgload::load_all("plant", quiet=TRUE)); options(width=115)
theta_h<-0.000157; K_s<-1
mkleaf<-function(nctrl=100) Leaf(vcmax_25=100, jmax_25=100*167, c=2.04, b=3, psi_crit=5, root_c=2.65,
  root_b=1.29, root_psi_crit=1.29*(log(1/0.05))^(1/2.65), beta2=1, a=0.3, curv_fact_elec_trans=0.7,
  curv_fact_colim=0.99, GSS_tol_abs=1e-6, vulnerability_curve_ncontrol=nctrl, ci_abs_tol=1e-6,
  ci_niter=1000, g1_TF24=46.32995, beta_R_H=3.4e3, beta_R_V=9.4e4)
timeit<-function(f,reps){f();t<-Sys.time();for(i in seq_len(reps))f();as.numeric(Sys.time()-t,units="secs")*1e6/reps}
sp<-function(L,psi,nlay,h=10){ ps<-rep(psi,nlay); sd<-seq(1,by=1,length.out=nlay); mr<-rep(1/nlay,nlay)
  L$set_physiology(area_leaf=0.05, mass_root_prop=mr, rho=608, a_bio=0.0245, PPFD=900, psi_soil=ps,
   soil_depth=sd, leaf_specific_conductance_max=K_s*theta_h/h, atm_vpd=2, ca=40,
   sapwood_volume_per_leaf_area=theta_h*h, leaf_temp=25, atm_o2_kpa=21, atm_kpa=101.3) }

# R->C++ dispatch overhead estimate (cheap active-binding get)
L<-mkleaf(); sp(L,2,1); ovh<-timeit(function() L$PPFD_, 20000)
cat(sprintf("R->C++ dispatch overhead (active-binding get) ~ %.2f us\n\n", ovh))

# (1) does set_physiology scale with vulnerability_curve_ncontrol? (member-dep, theta-indep cache)
cat("set_physiology cost vs vulnerability_curve_ncontrol (member/theta-independent build?):\n")
for(nc in c(10,100,500,2000)){ L<-mkleaf(nc); t<-timeit(function() sp(L,2,1), 3000)
  cat(sprintf("   ncontrol=%5d : %.2f us\n", nc, t)) }

# (2) set_physiology & evaluate vs soil layers (theta-dimension-dependent work)
cat("\nset_physiology / evaluate / dprofit vs soil layers (theta-dependent soil-side work):\n")
for(nl in c(1,5,20)){ L<-mkleaf(); sp(L,2,nl); L$find_root_collar_psi(); q<- -L$root_collar_psi_
  ts<-timeit(function() sp(L,2,nl), 3000)
  te<-timeit(function(){ sp(L,2,nl); L$evaluate_root_collar_psi(q) }, 3000)
  td<-timeit(function(){ sp(L,2,nl); L$evaluate_root_collar_psi(q); L$dprofit_droot_collar_psi(q) }, 3000)
  cat(sprintf("   layers=%2d : set_phys=%.2f  +evaluate=%.2f  +dprofit=%.2f  (evaluate=%.2f dprofit=%.2f)\n",
      nl, ts, te, td, te-ts, td-te)) }
cat("\nInterpretation: dispatch overhead is subtracted from all; the theta-dependent micro cost is the\n")
cat("soil-layer-scaling part of (evaluate+dprofit); the theta-INDEPENDENT setup (temp/photo/vuln, PPFD)\n")
cat("is cacheable once per leg per member.\n")
