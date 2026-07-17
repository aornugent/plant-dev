#!/usr/bin/env Rscript
# ============================================================================
# MRI multi-rate vs global adaptive RK45 on the REAL plant TF24 / TF24f patch.
#
# Premise (measured on the real patch, real_patch_probe.R): the 5 soil states are
# ~300x faster than the cohort/light block. A single global step size therefore
# forces the EXPENSIVE full-patch RHS (light-field scan + per-cohort hydraulics)
# to be re-evaluated at the soil's fast rate. MRI evaluates the full patch only at
# the daily macro cadence and sub-cycles the soil with a CHEAP soil-only RHS
# (real TF24 physics; cohort water demand frozen across the macro step).
#
# On the SAME seeded stand, over a bounded window under challenging rainfall
# (isolating the soil integrator from the SCM's demographic overflow guard,
# issue #550), we compare:
#   * accuracy  : MRI soil trajectory vs a tight global RK45 reference
#   * stability : completes without blow-up, drought -> monsoon
#   * cost      : EXPENSIVE full-patch derivs() calls (machine-independent proxy)
# ============================================================================
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE))
here <- "/home/user/plant-dev/scripts/tf24-multirate"
options(width=115)
args <- commandArgs(trailingOnly=TRUE)
MODEL <- if (length(args)>=1) args[1] else "TF24"      # "TF24" or "TF24f"
ENVT  <- "TF24_Env"
Tend  <- if (length(args)>=2) as.integer(args[2]) else 60L

# ---- rainfall scenarios (mm/day) -------------------------------------------
gen_rain <- function(seed, ndays=365, p01b=0.09, p11b=0.38, shape=0.6, scaleb=11, occ=1) {
  set.seed(seed); doy<-(seq_len(ndays)-1)%%365; season<-(1+cos(2*pi*(doy-15)/365))/2
  p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ); p11<-pmin(0.95,0.15+p11b*season^1.5)
  wet<-logical(ndays); for(t in 2:ndays) wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t])
  scale<-4+scaleb*season; rain<-numeric(ndays); rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet])
  rain[rain<0.1]<-0; round(rain,2)
}
scen <- list(drought=gen_rain(5,occ=0.18,scaleb=6), dry=gen_rain(7,occ=0.45,scaleb=7),
             semiarid=gen_rain(24), wet=gen_rain(11,occ=1.8,scaleb=16),
             monsoon=gen_rain(2,occ=0.7,shape=0.35,scaleb=45))
sel <- if (length(args)>=3) strsplit(args[3],",")[[1]] else names(scen)
scen <- scen[sel]
# Rainfall evaluator that mirrors the patch EXACTLY: extrinsic_drivers_set_variable
# builds an INTERPOLATED (spline) driver, so a step function would desync the cheap
# soil RHS from the patch off the integer knots. Query the real interpolator instead.
rain_fn_factory <- function(series){
  e<-Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall",0:(length(series)-1),series)
  function(t) e$extrinsic_drivers_evaluate("rainfall", t)
}

# ---- real TF24 soil physics parameters (from tf24_environment.h) ------------
SAT<-0.428; KSAT<-163.0411; NPSI<-6.57; A_INFIL<-1; B_INFIL<-8; DZ<-0.3; RESID<-1e-2
Kf    <- function(th) KSAT*(pmax(th,0)/SAT)^(2*NPSI+3)
infilf<- function(th0,r) r*max(0, 1 - A_INFIL*(th0/SAT)^B_INFIL)
# cheap soil-only RHS: real drainage/infiltration; cohort demand U frozen over macro
soil_rhs <- function(th, t, U, rfn){
  r<-rfn(t); win<-numeric(5); wout<-Kf(th)
  win[1]<-infilf(th[1],r); for(i in 2:5) win[i]<-wout[i-1]
  rate<-(win-wout-U)/DZ; guard<-(th<=RESID)&(rate<0); rate[guard]<-0; rate
}
# soil RHS with a soil-moisture-RESPONSIVE uptake (U supplied as a per-layer fn of theta)
soil_rhs_fn <- function(th, t, Ufn, rfn){
  r<-rfn(t); win<-numeric(5); wout<-Kf(th); U<-Ufn(th)
  win[1]<-infilf(th[1],r); for(i in 2:5) win[i]<-wout[i-1]
  rate<-(win-wout-U)/DZ; guard<-(th<=RESID)&(rate<0); rate[guard]<-0; rate
}
uptake_from <- function(th, deriv_soil, t, rfn){           # back out frozen U at macro start
  r<-rfn(t); win<-numeric(5); wout<-Kf(th)
  win[1]<-infilf(th[1],r); for(i in 2:5) win[i]<-wout[i-1]
  win - wout - deriv_soil*DZ
}

# ---- adaptive RK (Cash-Karp 4(5)); counts rhs() calls (the cost proxy) ------
ck <- list(a=c(1/5,3/10,3/5,1,7/8),
  b=list(c(1/5),c(3/40,9/40),c(3/10,-9/10,6/5),c(-11/54,5/2,-70/27,35/27),
         c(1631/55296,175/512,575/13824,44275/110592,253/4096)),
  c5=c(37/378,0,250/621,125/594,0,512/1771),
  c4=c(2825/27648,0,18575/48384,13525/55296,277/14336,1/4))
adaptive <- function(rhs, y0, t0, t1, atol, rtol, hmax){
  y<-y0; t<-t0; h<-min(hmax,(t1-t0)); evals<-0L; nstep<-0L
  repeat{
    if(t>=t1-1e-12) break
    if(t+h>t1) h<-t1-t
    k<-vector("list",6); k[[1]]<-rhs(y,t); evals<-evals+1L
    for(s in 2:6){ ys<-y; for(j in 1:(s-1)) ys<-ys+h*ck$b[[s-1]][j]*k[[j]]
      k[[s]]<-rhs(ys,t+ck$a[s-1]*h); evals<-evals+1L }
    y5<-y; y4<-y; for(s in 1:6){ y5<-y5+h*ck$c5[s]*k[[s]]; y4<-y4+h*ck$c4[s]*k[[s]] }
    sc<-atol+rtol*pmax(abs(y),abs(y5)); err<-max(abs(y5-y4)/sc)
    if(!is.finite(err)){                     # NaN/Inf stage: shrink or give up
      if(h<=1e-9){ y<-y5; break }; h<-h*0.1; next }
    if(err<=1 || h<=1e-9){ t<-t+h; y<-y5; nstep<-nstep+1L
      h<-min(hmax, h*min(5,max(0.2,0.9*err^(-0.2)))) }
    else h<-h*max(0.1,0.9*err^(-0.25))
  }
  list(y=y, evals=evals, nstep=nstep)
}

# ---- build a real seeded stand under a given rainfall driver ----------------
p0 <- scm_base_parameters(MODEL); p0$max_patch_lifetime <- 30
p1 <- add_strategies(p0, trait_matrix(0.0825, "lma"))
stand_h <- c(14,10,7,5,3.5,2.2,1.3,0.7)             # realistic mixed-size stand
stand_d <- c(0.015,0.03,0.06,0.12,0.25,0.6,1.5,4.0)
seed_patch <- function(series){
  env <- Environment("TF24"); env$extrinsic_drivers_set_variable("rainfall",0:(length(series)-1),series)
  st  <- make_initial_state(p1, heights=stand_h, densities=stand_d, env=env, ctrl=Control())
  p2  <- set_initial_state(p1, st)
  scm <- SCM(MODEL, ENVT)(p2, env, Control())
  scm$patch
}
soil_idx <- function(patch){ ne<-patch$environment$ode_size; ns<-patch$ode_size; (ns-ne+1):(ns-ne+5) }

fin <- function(v) all(is.finite(v))
# We compare the SOIL integrator on the real coupled patch with the cohort block
# frozen (the slow block barely moves over a day; the demographic dynamics are a
# separate, now-fixed concern, #554). Only soil states are varied, so the raw
# patch RHS is never handed an overshooting cohort state (which segfaults).
#
# GLOBAL: the full (expensive) patch RHS is evaluated at every soil-limited RK
# stage -- exactly what plant's single-step-size solver pays. Cohorts frozen at y0.
run_global <- function(series, atol, rtol){
  patch<-seed_patch(series); si<-soil_idx(patch); y0<-patch$ode_state
  fe<-0L
  rhs<-function(th,t){ fe<<-fe+1L; yt<-y0; yt[si]<-th; patch$derivs(yt,t)[si] }
  daily<-0:Tend; sav<-matrix(NA,length(daily),5); th<-y0[si]; sav[1,]<-th; horizon<-0
  t0<-Sys.time()
  for(m in 1:(length(daily)-1)){
    res<-adaptive(rhs,th,daily[m],daily[m+1],atol,rtol,1.0)
    if(!fin(res$y)) break
    th<-res$y; sav[m+1,]<-th; horizon<-daily[m+1]
  }
  list(theta=sav, full_evals=fe, horizon=horizon,
       wall_ms=as.numeric(Sys.time()-t0,units="secs")*1000)
}
# MRI: refresh the (expensive) cohort water demand `nsub` times/day; sub-cycle the
# soil in between with the CHEAP soil-only RHS, that demand held. The soil block is
# STIFF and positivity-clamped (fast timescale ~0.003 d), so the sub-cycle uses a
# small fixed-step clamped explicit Euler (robust where an adaptive high-order stage
# straddles the clamp and locks onto a spurious state). Cheap evals are soil-only;
# only `nsub x days` EXPENSIVE full-patch evals are paid. Records daily soil theta.
HS_CAP <- 5e-3   # cap on the soil sub-step (day)
# local explicit-stability limit: drainage Jacobian ~ d/dθ[K(θ)/dz] = (2n+3)K/(θ·dz),
# which reaches ~1400/day at wet θ (fast timescale ~7e-4 d). Step below ~1.5/λ.
soil_h <- function(th){ lam<-max((2*NPSI+3)*Kf(th)/(pmax(th,1e-3)*DZ)); min(HS_CAP, 1.5/max(lam,1)) }
run_mri <- function(series, atol, rtol, nsub=1L){
  patch<-seed_patch(series); si<-soil_idx(patch); y0<-patch$ode_state; rfn<-rain_fn_factory(series)
  fe<-0L; ce<-0L; rdt<-1/nsub
  sav<-matrix(NA,Tend+1,5); th<-y0[si]; sav[1,]<-th; horizon<-0
  U<-NULL; last<--Inf; t<-0; nextday<-1L
  t0<-Sys.time()
  while(t < Tend-1e-12){
    if(t-last>=rdt-1e-9){ yt<-y0; yt[si]<-th; d0<-patch$derivs(yt,t)[si]; fe<-fe+1L
      U<-uptake_from(th,d0,t,rfn); last<-t }                     # refresh expensive demand
    h<-min(soil_h(th), Tend-t, nextday-t)                        # stability-limited substep
    th<-pmin(pmax(th+h*soil_rhs(th,t,U,rfn),RESID),SAT-1e-6); ce<-ce+1L; t<-t+h
    if(!fin(th)) break
    if(abs(t-nextday)<1e-9){ sav[nextday+1,]<-th; horizon<-nextday; nextday<-nextday+1L }
  }
  list(theta=sav, full_evals=fe, cheap_evals=ce, horizon=horizon,
       wall_ms=as.numeric(Sys.time()-t0,units="secs")*1000)
}
# ============================================================================
NSUBS <- if (length(args)>=4) as.integer(strsplit(args[4],",")[[1]]) else c(1L,10L,20L,50L,100L)
p_probe<-seed_patch(scen[[1]])
cat(sprintf("Model %s: seeded stand = %d cohorts, patch ode_size = %d (5 soil + 4 aux + %d cohort states). Window %d d.\n",
    MODEL, length(stand_h), p_probe$ode_size, p_probe$ode_size-9, Tend))
{ si<-soil_idx(p_probe); y<-p_probe$ode_state; d0<-p_probe$derivs(y,0); rfn<-rain_fn_factory(scen[[1]])
  U<-uptake_from(y[si],d0[si],0,rfn); chk<-max(abs(soil_rhs(y[si],0,U,rfn)-d0[si]))
  cat(sprintf("cheap soil-RHS vs real patch derivs at t=0: max|diff| = %.2e\n\n", chk)) }

cat("Soil integrator on the real coupled patch, cohorts frozen (the slow block). The cohort water\n")
cat("demand (per-layer root uptake) is strongly, NON-SEPARABLY soil-moisture-dependent (the plant\n")
cat("redistributes uptake across the whole profile via the hydraulic solve), so it must be REFRESHED\n")
cat("as the soil evolves -- freezing it fails. We sweep the refresh cadence (refreshes/day):\n")
cat("full_g = expensive full-patch RHS evals in the global single-rate run (soil-limited step rate);\n")
cat("full_M = expensive evals in MRI (= refreshes/day x days); err = max|dθ| vs global (daily grid);\n")
cat("cut = full_g/full_M (reduction in expensive evals). The soil sub-cycle is cheap (soil-only).\n\n")
res<-list()
for(sn in names(scen)){
  series<-scen[[sn]]
  g<-run_global(series, 1e-8,1e-8)
  cat(sprintf("--- %-9s (%4.0f mm/yr): global single-rate = %d expensive evals (%.0f/day), %.0f ms ---\n",
      sn, sum(series), g$full_evals, g$full_evals/Tend, g$wall_ms)); flush(stdout())
  cat(sprintf("    %8s | %8s | %9s | %8s | %9s\n","refr/day","full_M","err|dθ|","cut","cheap"))
  rows<-list()
  for(ns in NSUBS){
    r<-run_mri(series, 1e-8,1e-8, ns)
    err<-max(abs(r$theta-g$theta),na.rm=TRUE); cut<-g$full_evals/max(r$full_evals,1)
    ok<-if(err<1e-3) "  <-- tracks global (err<1e-3)" else ""
    cat(sprintf("    %8d | %8d | %9.2e | %7.0fx | %9d%s\n", ns, r$full_evals, err, cut, r$cheap_evals, ok)); flush(stdout())
    rows[[as.character(ns)]]<-list(err=err,cut=cut,full=r$full_evals,cheap=r$cheap_evals)
  }
  res[[sn]]<-list(g=list(full_evals=g$full_evals,wall_ms=g$wall_ms,theta=g$theta),rows=rows)
}
saveRDS(list(model=MODEL,Tend=Tend,scen=scen,NSUBS=NSUBS,res=res),
        file.path(here,sprintf("data/bench_real_%s.rds",MODEL)))
cat(sprintf("\nwrote data/bench_real_%s.rds\n", MODEL))
