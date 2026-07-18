#!/usr/bin/env Rscript
# E2 (Oracle): the aggregate coupling a_ℓ(θ) = Σⱼ c_ℓ(x_j, θ) is a density-weighted quadrature
# over the cohort (member) coordinate. Collocation viability = how few cohorts m reconstruct the
# aggregate the full N-cohort stand gives. Faithful, real-physiology test: represent the SAME
# continuous size distribution at increasing cohort counts m, compute the aggregate per-layer
# uptake (backed out of the real patch derivs), and measure convergence vs a fine reference.
# If the aggregate converges by m ~ O(10), collocation with m << N (large stands N~100s-800s) is
# the decisive lever. Done at wet / mid / dry soil states (the coupling's regimes).
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE)); options(width=115)
gen_rain<-function(seed,ndays=365,p01b=0.09,p11b=0.38,shape=0.6,scaleb=11,occ=1){set.seed(seed);doy<-(seq_len(ndays)-1)%%365;season<-(1+cos(2*pi*(doy-15)/365))/2;p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ);p11<-pmin(0.95,0.15+p11b*season^1.5);wet<-logical(ndays);for(t in 2:ndays)wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t]);scale<-4+scaleb*season;rain<-numeric(ndays);rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet]);rain[rain<0.1]<-0;round(rain,2)}
rr<-gen_rain(24)
p0<-scm_base_parameters("TF24"); p0$max_patch_lifetime<-30
p1<-add_strategies(p0, trait_matrix(0.0825,"lma"))
SAT<-0.428;KSAT<-163.0411;NPSI<-6.57;A<-1;B<-8;DZ<-0.3
Kf<-function(th)KSAT*(pmax(th,0)/SAT)^(2*NPSI+3); inf<-function(t0,r)r*max(0,1-A*(t0/SAT)^B)

# same continuous size distribution, sampled at m cohorts: heights log-spaced [0.5,14],
# density rho(h) ~ h^-1.8 (a plausible declining size structure), fixed scale.
make_patch <- function(m){
  env<-Environment("TF24"); env$extrinsic_drivers_set_variable("rainfall",0:364,rr)
  h<-exp(seq(log(0.5), log(14), length.out=m)); d<-0.05*(h/0.5)^-1.8
  st<-make_initial_state(p1, heights=h, densities=d, env=env, ctrl=Control())
  SCM("TF24","TF24_Env")(set_initial_state(p1,st), env, Control())$patch
}
# aggregate per-layer uptake from the real patch derivs at soil state theta
agg_uptake <- function(patch, theta, t=3.0){
  ne<-patch$environment$ode_size; ns<-patch$ode_size; si<-(ns-ne+1):(ns-ne+5)
  y<-patch$ode_state; y[si]<-theta; dd<-patch$derivs(y,t)[si]
  r<-env_rain(t); win<-numeric(5); wo<-Kf(theta); win[1]<-inf(theta[1],r); for(i in 2:5) win[i]<-wo[i-1]
  win - wo - dd*DZ
}
env_rain<-local({ e<-Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall",0:364,rr); function(t) e$extrinsic_drivers_evaluate("rainfall",t) })

thetas <- list(wet=rep(0.30,5), mid=rep(0.18,5), dry=c(0.06,0.10,0.14,0.16,0.18))
ms <- c(3,5,8,12,20,40,80)
cat("Aggregate per-layer uptake vs cohort count m; reference = m=80. Error = max_layer |a_m - a_80|/||a_80||.\n\n")
for(nm in names(thetas)){
  th<-thetas[[nm]]
  As<-lapply(ms, function(m) agg_uptake(make_patch(m), th))
  ref<-As[[length(As)]]; refn<-sqrt(sum(ref^2))
  cat(sprintf("theta=%-4s (||a||=%.4f):\n", nm, refn))
  cat(sprintf("   %6s %12s %12s\n","m","rel_err","abs_err"))
  for(i in seq_along(ms)) cat(sprintf("   %6d %12.2e %12.2e\n", ms[i], sqrt(sum((As[[i]]-ref)^2))/refn, max(abs(As[[i]]-ref))))
  cat("\n")
}
cat("If rel_err is small by m ~ 8-20 across wet->dry, collocation over cohorts (m<<N) reconstructs\n")
cat("the aggregate -> attacks the O(N) factor directly (the bigger lever than warm-start, per E1).\n")
