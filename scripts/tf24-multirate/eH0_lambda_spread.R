#!/usr/bin/env Rscript
# E-H0 (Oracle H0-response, triage step 5): the shadow-price-of-water spread across cohorts.
# H0 exact collapse fails for TF24 (u=theta enters a member-local hydraulic constraint; the byproduct
# is a primal water flux, not a Lagrangian marginal). The one measurement that could still change the
# build: is the per-cohort shadow price of water lambda_j = (dP_j/dtheta)/(dE_j/dtheta) member-INDEPENDENT?
#   tight spread -> a shared stock-dependent tariff phi(theta) (priced model 3a) or a control-variate
#                   hybrid a = Kbar*grad_u V + r (3b) become live alternatives to tracked controls.
#   wide spread  -> the flux is genuinely member-specific; 3a/3b are out; the H0 thread closes and the
#                   committed tracked-control (TF24f) + m-collocation build is the answer.
# Faithful vehicle (sidesteps the standalone-leaf degeneracy that sank h0_envelope_check.R): a real
# seeded stand with its frozen canopy light; per-cohort P_j (leaf profit_) and E_j (E_up_, water flux)
# read from the real solver via Individual$compute_rates(env); central FD in a uniform soil-moisture
# perturbation. Mapped across soil levels theta to trace Kbar(u) ~ 1/lambda_bar.
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)); options(width=120)

gen_rain<-function(seed,ndays=365,p01b=0.09,p11b=0.38,shape=0.6,scaleb=11,occ=1){set.seed(seed);doy<-(seq_len(ndays)-1)%%365;season<-(1+cos(2*pi*(doy-15)/365))/2;p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ);p11<-pmin(0.95,0.15+p11b*season^1.5);wet<-logical(ndays);for(t in 2:ndays)wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t]);scale<-4+scaleb*season;rain<-numeric(ndays);rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet]);rain[rain<0.1]<-0;round(rain,2)}
rr<-gen_rain(24)
p0<-scm_base_parameters("TF24"); p0$max_patch_lifetime<-30
p1<-add_strategies(p0, trait_matrix(0.0825,"lma"))
# a real stand: a size-structured cohort ladder, its densities declining with height
H <- c(14,10,7,5,3.5,2.2,1.3,0.7); D <- c(0.015,0.03,0.06,0.12,0.25,0.6,1.5,4.0)
env<-Environment("TF24"); env$extrinsic_drivers_set_variable("rainfall",0:364,rr)
st<-make_initial_state(p1,heights=H,densities=D,env=env,ctrl=Control())
patch<-SCM("TF24","TF24_Env")(set_initial_state(p1,st),env,Control())$patch
patch$compute_environment()            # freeze the canopy light profile (the slow block x is frozen)
penv<-patch$environment
nL<-penv$get_soil_number_of_depths()
open<-sapply(H,function(z)penv$get_environment_at_height(z))
cat(sprintf("Stand: %d cohorts, heights %s\n  canopy openness %s  (%d soil layers)\n\n",
    length(H), paste(H,collapse=","), paste(sprintf('%.2f',open),collapse=","), nL))

# per-cohort leaf objective (profit_, per leaf area) and water flux (E_up_, per leaf area) at uniform theta
evalc <- function(hj, theta){
  penv$set_soil_water_state(rep(theta,nL))
  ind<-Individual("TF24","TF24_Env")(p1$strategies[[1]]); ind$set_state("height",hj)
  ind$compute_rates(penv)
  c(P=ind$aux("profit"), E=ind$aux("E_up_"), q=ind$aux("opt_root_psi"))
}
# central FD of (P,E) in a uniform theta perturbation; lambda = dP/dE (marginal carbon value of water)
lambda_at <- function(hj, theta, dth=2e-3){
  hp<-evalc(hj,theta+dth); hm<-evalc(hj,theta-dth)
  dP<-(hp["P"]-hm["P"])/(2*dth); dE<-(hp["E"]-hm["E"])/(2*dth)
  c(lambda=unname(dP/dE), dP=unname(dP), dE=unname(dE), q=unname(evalc(hj,theta)["q"]))
}

thetas <- c(0.34,0.26,0.20,0.16)
cat("lambda_j = (dP_j/dtheta)/(dE_j/dtheta), per cohort, central FD (dtheta=2e-3). NA = leaf solve\n")
cat("left its domain at that (h,theta) (the near-singular dry bound).\n\n")
summ <- list()
for(theta in thetas){
  cat(sprintf("theta = %.2f\n", theta))
  cat(sprintf("  %6s | %12s %12s %12s %8s\n","h","lambda","dP/dtheta","dE/dtheta","q"))
  lam<-numeric(0)
  for(hj in H){
    r<-tryCatch(lambda_at(hj,theta), error=function(e) c(lambda=NA,dP=NA,dE=NA,q=NA))
    ok <- is.finite(r["lambda"])
    if(ok) lam<-c(lam, r["lambda"])
    cat(sprintf("  %6.1f | %12.4g %12.4g %12.4g %8.3f\n", hj, r["lambda"], r["dP"], r["dE"], r["q"]))
  }
  if(length(lam)>=2){
    cv <- sd(lam)/abs(mean(lam)); rng <- max(lam)/min(lam)
    cat(sprintf("  --> lambda_bar=%.4g  CV=%.1f%%  max/min=%.2f  (n=%d cohorts solved)\n\n",
        mean(lam), 100*cv, rng, length(lam)))
    summ[[sprintf('%.2f',theta)]] <- c(lambda_bar=mean(lam), CV=cv, ratio=rng, n=length(lam))
  } else cat("  --> too few cohorts solved to summarize\n\n")
}
cat("=== lambda_bar(theta): the aggregate price map (Kbar ~ 1/lambda_bar) ===\n")
for(nm in names(summ)) cat(sprintf("  theta=%s : lambda_bar=%.4g  CV=%.1f%%  max/min=%.2f\n",
    nm, summ[[nm]]["lambda_bar"], 100*summ[[nm]]["CV"], summ[[nm]]["ratio"]))
cat("\nVERDICT: CV small (say <~15-20%) and max/min near 1 across cohorts => lambda_j is member-near-invariant\n")
cat("  => a shared tariff phi(theta) is defensible (3a/3b live). CV large / max/min >> 1 => member-specific\n")
cat("  price => 3a/3b are out, tracked-control build stands. Trend of lambda_bar(theta) = the price map K(u).\n")
