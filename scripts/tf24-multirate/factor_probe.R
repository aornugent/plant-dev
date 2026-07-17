#!/usr/bin/env Rscript
# LEAN PROBE for coupling-factoring (#1): is freezing the light field worth it?
# A full patch derivs = compute_environment() [light-field scan over cohorts, the
# SLOW/expensive piece we want to freeze] + compute_rates() [per-cohort physiology
# reading the frozen light + current soil theta -> resource_depletion -> soil balance,
# the FAST piece we want in the sub-cycle]. Both are exposed in R. Measure the split
# and how each scales with cohort count, before designing the C++ seam for #2.
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE))
here<-"/home/user/plant-dev/scripts/tf24-multirate"; options(width=110)

gen_rain<-function(seed,ndays=365,p01b=0.09,p11b=0.38,shape=0.6,scaleb=11,occ=1){set.seed(seed);doy<-(seq_len(ndays)-1)%%365;season<-(1+cos(2*pi*(doy-15)/365))/2;p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ);p11<-pmin(0.95,0.15+p11b*season^1.5);wet<-logical(ndays);for(t in 2:ndays)wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t]);scale<-4+scaleb*season;rain<-numeric(ndays);rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet]);rain[rain<0.1]<-0;round(rain,2)}
rr<-gen_rain(24)
p0<-scm_base_parameters("TF24"); p0$max_patch_lifetime<-30
p1<-add_strategies(p0, trait_matrix(0.0825,"lma"))

# build a seeded stand of a given cohort count (log-spaced heights, ecological densities)
seed_stand <- function(ncoh){
  env<-Environment("TF24"); env$extrinsic_drivers_set_variable("rainfall",0:364,rr)
  h<-exp(seq(log(14),log(0.5),length.out=ncoh)); d<-0.02*(h/max(h))^-1.3
  st<-make_initial_state(p1,heights=h,densities=d,env=env,ctrl=Control())
  SCM("TF24","TF24_Env")(set_initial_state(p1,st),env,Control())$patch
}

timeit <- function(f, reps){ t<-Sys.time(); for(i in seq_len(reps)) f(); as.numeric(Sys.time()-t,units="secs")*1000/reps }

cat(sprintf("%-6s | %10s %10s %10s | %8s %8s\n","ncoh","derivs_ms","cenv_ms","crates_ms","cenv%","crates%"))
for(ncoh in c(5,10,20,40,80)){
  patch<-seed_stand(ncoh); y<-patch$ode_state
  reps<-max(20, as.integer(2000/ncoh))
  t_der <- timeit(function() patch$derivs(y,3.0), reps)                 # full RHS
  t_env <- timeit(function() patch$compute_environment(), reps)         # light-field scan (SLOW)
  t_rat <- timeit(function() patch$compute_rates(), reps)               # physiology + soil (FAST piece)
  cat(sprintf("%-6d | %10.3f %10.3f %10.3f | %7.0f%% %7.0f%%\n",
      ncoh, t_der, t_env, t_rat, 100*t_env/t_der, 100*t_rat/t_der))
}
cat("\nIf cenv% dominates and grows with ncoh, freezing the light field across the macro step\n")
cat("is the win; crates() is the cheap theta-response to run in the soil sub-cycle.\n")
