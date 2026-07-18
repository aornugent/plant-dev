#!/usr/bin/env Rscript
# E2 (Oracle): tracked control vs solved optimum. TF24f carries the collar potential q as a
# state (dq/dt = k*dprofit); TF24 re-optimises it every step (QSS). Drive a single real leaf's
# soil potential over a fast dry-down episode and compare the tracked q (gradient relaxation)
# against the QSS optimum q*, sweeping k. Sets the acceptable lag and validates the variant
# change: is there a k giving small uptake error during fast excursions without excessive stiffness?
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)); options(width=115)
theta_h<-0.000157; h<-10; K_s<-1
L <- Leaf(vcmax_25=100, jmax_25=100*167, c=2.04, b=3, psi_crit=5, root_c=2.65, root_b=1.29,
  root_psi_crit=1.29*(log(1/0.05))^(1/2.65), beta2=1, a=0.3, curv_fact_elec_trans=0.7,
  curv_fact_colim=0.99, GSS_tol_abs=1e-6, vulnerability_curve_ncontrol=100, ci_abs_tol=1e-6,
  ci_niter=1000, g1_TF24=46.32995, beta_R_H=3.4e3, beta_R_V=9.4e4)
setphys<-function(psi) L$set_physiology(area_leaf=0.05, mass_root_prop=1, rho=608, a_bio=0.0245,
  PPFD=900, psi_soil=psi, soil_depth=1, leaf_specific_conductance_max=K_s*theta_h/h, atm_vpd=2, ca=40,
  sapwood_volume_per_leaf_area=theta_h*h, leaf_temp=25, atm_o2_kpa=21, atm_kpa=101.3)
qopt<-function(psi){ setphys(psi); L$find_root_collar_psi(); c(q=-L$root_collar_psi_, up=L$soil_consumption_[1]) }
eval_q<-function(psi,q){ setphys(psi); up<-L$evaluate_root_collar_psi(q); c(dpr=L$dprofit_droot_collar_psi(q), up=L$soil_consumption_[1]) }

# a fast soil dry-down then re-wet episode in psi_soil (MPa), over ~4 days, dt=0.005 d
tt<-seq(0,4,by=0.005); n<-length(tt)
psi_t <- 0.5 + 4.0*pmin(1, pmax(0,(tt-0.5)/1.0)) * exp(-pmax(0,tt-1.5)/0.8) + 0.3  # rise to ~dry, relax
psi_t <- pmax(0.3, psi_t)
# QSS truth
qs<-sapply(psi_t, function(p) qopt(p)); qstar<-qs["q",]; upstar<-qs["up",]
cat(sprintf("episode: psi_soil %.2f -> %.2f MPa; q* range [%.3f, %.3f]\n\n", min(psi_t), max(psi_t), min(qstar), max(qstar)))
cat(sprintf("%8s | %10s %10s | %10s %10s | %6s\n","k","max|dq|","rms|dq|","max|dup|/up","rms rel up","stiff"))
for(k in c(0.3,1,3,10,30,100,300)){
  q<-qstar[1]; qtr<-numeric(n); uptr<-numeric(n); qtr[1]<-q
  for(i in 2:n){ dt<-tt[i]-tt[i-1]; e<-eval_q(psi_t[i-1], q); q<-q + dt*k*e["dpr"]; q<-max(1e-3,q)
    qtr[i]<-q; uptr[i]<-eval_q(psi_t[i], q)["up"] }
  dq<-abs(qtr-qstar); dup<-abs(uptr-upstar); rel<-dup/pmax(abs(upstar),1e-9)
  stiff<-k*max(abs(qs["q",]))  # crude stiffness proxy (k * scale)
  cat(sprintf("%8.0f | %10.3e %10.3e | %10.3e %10.3e | %6.0f\n", k, max(dq), sqrt(mean(dq^2)),
      max(rel), sqrt(mean(rel^2)), stiff))
}
cat("\nA k with small uptake error (rms rel << 1%) validates tracked-q as the fast model; larger k -> tighter\n")
cat("tracking but stiffer q-ODE (Rosenbrock-W territory). The knee is the operating point for #2.\n")
