# H0 envelope check: at the optimum, is the byproduct water uptake c_l (soil_consumption_[l])
# equal (or proportional) to the marginal optimized profit wrt soil potential, d(max profit)/d(psi_soil_l)?
# If so, a = grad_u V (V = sum of max profit) and the fast dynamics never reference p* -> unifies
# TF24 (argmax) and TF24f (tracked) into ONE gradient-coupled system.
suppressMessages(pkgload::load_all("plant", quiet=TRUE)); options(width=115)
mkleaf<-function() Leaf(vcmax_25=100, jmax_25=100*167, c=2.04, b=3, psi_crit=5, root_c=2.65, root_b=1.29,
  root_psi_crit=1.29*(log(1/0.05))^(1/2.65), beta2=1, a=0.3, curv_fact_elec_trans=0.7,
  curv_fact_colim=0.99, GSS_tol_abs=1e-8, vulnerability_curve_ncontrol=100, ci_abs_tol=1e-8,
  ci_niter=1000, g1_TF24=46.32995, beta_R_H=3.4e3, beta_R_V=9.4e4)
th<-0.000157
setp<-function(L,psi,PPFD=1800,vpd=1,h=5,area=1.0) L$set_physiology(area_leaf=area, mass_root_prop=rep(1/length(psi),length(psi)),
  rho=608,a_bio=0.0245,PPFD=PPFD,psi_soil=psi,soil_depth=seq(0.3,by=0.3,length.out=length(psi)),
  leaf_specific_conductance_max=1*th/h, atm_vpd=vpd, ca=40, sapwood_volume_per_leaf_area=th*h,
  leaf_temp=25, atm_o2_kpa=21, atm_kpa=101.3)
# find a TRANSPIRING single-layer config (profit>0, uptake>0)
cat("search for a transpiring config (profit>0, uptake>0):\n")
found<-NULL
for(PPFD in c(1800,3000)) for(vpd in c(0.5,1)) for(area in c(1,4,10)) for(psv in c(0.1,0.3,0.6)){
  L<-mkleaf(); setp(L,psv,PPFD,vpd,area=area); L$find_root_collar_psi()
  if(is.finite(L$profit_) && L$profit_>0 && L$soil_consumption_[1]>1e-6){ found<-list(PPFD=PPFD,vpd=vpd,area=area,psv=psv); break }
}
if(is.null(found)){ cat("  no transpiring single-layer config found in sweep\n") } else {
  cat(sprintf("  found: PPFD=%g vpd=%g area=%g psi=%g\n", found$PPFD,found$vpd,found$area,found$psv)) }

# envelope test, multi-layer, at a transpiring config
psi<-c(0.3,0.5,0.8,1.2,1.8)
L<-mkleaf(); setp(L,psi,PPFD=3000,vpd=0.5,area=10); L$find_root_collar_psi()
P0<-L$profit_; up<-L$soil_consumption_
cat(sprintf("\nmulti-layer @ optimum: profit=%.4f  uptake(soil_consumption_)=%s\n", P0, paste(sprintf('%.4e',up),collapse=",")))
eps<-1e-4; dPdpsi<-numeric(length(psi))
for(l in seq_along(psi)){ pp<-psi; pp[l]<-pp[l]+eps; Lp<-mkleaf(); setp(Lp,pp,PPFD=3000,vpd=0.5,area=10); Lp$find_root_collar_psi()
  pm<-psi; pm[l]<-pm[l]-eps; Lm<-mkleaf(); setp(Lm,pm,PPFD=3000,vpd=0.5,area=10); Lm$find_root_collar_psi()
  dPdpsi[l]<-(Lp$profit_-Lm$profit_)/(2*eps) }
cat(sprintf("d(maxprofit)/d(psi_soil_l): %s\n", paste(sprintf('%+.4e',dPdpsi),collapse=",")))
cat(sprintf("ratio dP/dpsi : uptake      : %s\n", paste(sprintf('%+.3f',dPdpsi/up),collapse=",")))
cat("\nH0 holds if dP/dpsi_l == c_l (ratio ~1) or a consistent constant (proportional, a close cousin).\n")
