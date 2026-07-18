#!/usr/bin/env Rscript
# T1b: locate the near-bound "dead zone" mechanism. As the frozen stand's soil dries, track the soil
# tension psi_soil, the cohort's optimised operating point q (root_collar_psi), and its water uptake.
# Finding: the dead zone (constant uptake, zero gradient) begins where q PINS at the hydraulic critical
# potential (~ -5.9 MPa, psi_crit / runaway embolism) -- i.e. the numerical clamp coincides with the
# plant's hydraulic-failure threshold, TF24's central drought-mortality mechanism.
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)); options(width=125)
SAT<-0.428; apsi<-1.78e3; n<-6.57
psi_of<-function(th) apsi*(th/SAT)^(-n)/1e6   # matric potential, MPa
p0<-scm_base_parameters("TF24"); p0$max_patch_lifetime<-30
p1<-add_strategies(p0, trait_matrix(0.0825,"lma")); Lf<-p1$strategies[[1]]
env<-Environment("TF24"); env$extrinsic_drivers_set_variable("rainfall",0:364,rep(0,365))
H<-c(14,10,7,5,3.5,2.2,1.3,0.7); D<-c(0.015,0.03,0.06,0.12,0.25,0.6,1.5,4.0)
st<-make_initial_state(p1,heights=H,densities=D,env=env,ctrl=Control())
patch<-SCM("TF24","TF24_Env")(set_initial_state(p1,st),env,Control())$patch; patch$compute_environment()
penv<-patch$environment
cat(sprintf("%8s %13s %10s | %10s %12s\n","theta","psi_soil(MPa)","cap?","q(opt)","uptake"))
for(th in c(0.20,0.16,0.13,0.115,0.11,0.10,0.08,0.06,0.04,0.02)){
  penv$set_soil_water_state(rep(th,5))
  ind<-Individual("TF24","TF24_Env")(Lf); ind$set_state("height",7); ind$compute_rates(penv)
  cat(sprintf("%8.3f %13.3f %10s | %10.4f %12.4e\n", th, psi_of(th),
      if(psi_of(th)>=1e3)"psi-CAP" else "", ind$aux("opt_root_psi"), ind$aux("E_up_"))) }
cat("\nq pins at the hydraulic critical potential (~ -5.9 MPa) around theta~0.115 (psi_soil ~ 10 MPa);\n")
cat("below that the leaf solve is at its domain edge -> uptake frozen/NA, gradient dead. The clamp\n")
cat("coincides with hydraulic failure -- the reformulation should let the vulnerability curve run\n")
cat("smoothly to zero there (R-C), in the log-scarcity coordinate (R-D).\n")
