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
rain_at <- function(series, t){ d<-floor(t)+1; if(d<1)d<-1; if(d>length(series))d<-length(series); series[d] }

# ---- real TF24 soil physics parameters (from tf24_environment.h) ------------
SAT<-0.428; KSAT<-163.0411; NPSI<-6.57; A_INFIL<-1; B_INFIL<-8; DZ<-0.3; RESID<-1e-2
Kf    <- function(th) KSAT*(pmax(th,0)/SAT)^(2*NPSI+3)
infilf<- function(th0,r) r*max(0, 1 - A_INFIL*(th0/SAT)^B_INFIL)
# cheap soil-only RHS: real drainage/infiltration; cohort demand U frozen over macro
soil_rhs <- function(th, t, U, series){
  r<-rain_at(series,t); win<-numeric(5); wout<-Kf(th)
  win[1]<-infilf(th[1],r); for(i in 2:5) win[i]<-wout[i-1]
  rate<-(win-wout-U)/DZ; guard<-(th<=RESID)&(rate<0); rate[guard]<-0; rate
}
# soil RHS with a soil-moisture-RESPONSIVE uptake (U supplied as a per-layer fn of theta)
soil_rhs_fn <- function(th, t, Ufn, series){
  r<-rain_at(series,t); win<-numeric(5); wout<-Kf(th); U<-Ufn(th)
  win[1]<-infilf(th[1],r); for(i in 2:5) win[i]<-wout[i-1]
  rate<-(win-wout-U)/DZ; guard<-(th<=RESID)&(rate<0); rate[guard]<-0; rate
}
uptake_from <- function(th, deriv_soil, t, series){        # back out frozen U at macro start
  r<-rain_at(series,t); win<-numeric(5); wout<-Kf(th)
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
# MRI: refresh the (expensive) cohort water demand via ONE full patch RHS per
# daily macro; sub-cycle the soil with the CHEAP soil-only RHS in between.
run_mri <- function(series, atol, rtol){
  patch<-seed_patch(series); si<-soil_idx(patch); y0<-patch$ode_state
  fe<-0L; ce<-0L
  daily<-0:Tend; sav<-matrix(NA,length(daily),5); th<-y0[si]; sav[1,]<-th; horizon<-0
  t0<-Sys.time()
  for(m in 1:(length(daily)-1)){
    ta<-daily[m]; tb<-daily[m+1]
    yt<-y0; yt[si]<-th; d0<-patch$derivs(yt,ta)[si]; fe<-fe+1L   # ONE expensive eval/macro
    U<-uptake_from(th,d0,ta,series)                              # freeze cohort demand
    srhs<-function(x,t){ ce<<-ce+1L; soil_rhs(x,t,U,series) }
    sres<-adaptive(srhs,th,ta,tb,atol,rtol,0.5)
    if(!fin(sres$y)) break
    th<-sres$y; sav[m+1,]<-th; horizon<-tb
  }
  list(theta=sav, full_evals=fe, cheap_evals=ce, horizon=horizon,
       wall_ms=as.numeric(Sys.time()-t0,units="secs")*1000)
}
# MRI-R: θ-RESPONSIVE aggregate. At each macro start, probe the (expensive) uptake
# response to soil moisture by scaling θ over [residual, current] and reading the
# real patch demand; interpolate per-layer U_i(θ_i) during the cheap soil sub-cycle.
# Costs a few full evals per macro (vs 1 for the naive freeze) to recover accuracy.
NPROBE <- if (length(args)>=4) as.integer(args[4]) else 8L
build_uptake_fn <- function(patch, si, y0, th0, ta, series, fe_env){
  scales<-seq(1.0, 0.06, length.out=NPROBE)
  TH<-matrix(NA,NPROBE,5); UU<-matrix(NA,NPROBE,5)
  for(k in seq_len(NPROBE)){
    thp<-pmax(RESID*0.5, scales[k]*th0); yt<-y0; yt[si]<-thp
    d<-patch$derivs(yt,ta)[si]; assign("fe",get("fe",envir=fe_env)+1L,envir=fe_env)
    TH[k,]<-thp; UU[k,]<-uptake_from(thp,d,ta,series)
  }
  function(th) sapply(1:5, function(i){ o<-order(TH[,i])
    approx(TH[o,i],UU[o,i],xout=th[i],rule=2)$y })
}
run_mri_resp <- function(series, atol, rtol){
  patch<-seed_patch(series); si<-soil_idx(patch); y0<-patch$ode_state
  env<-environment(); env$fe<-0L; ce<-0L
  daily<-0:Tend; sav<-matrix(NA,length(daily),5); th<-y0[si]; sav[1,]<-th; horizon<-0
  t0<-Sys.time()
  for(m in 1:(length(daily)-1)){
    ta<-daily[m]; tb<-daily[m+1]
    Ufn<-build_uptake_fn(patch, si, y0, th, ta, series, env)   # few expensive evals/macro
    srhs<-function(x,t){ ce<<-ce+1L; soil_rhs_fn(x,t,Ufn,series) }
    sres<-adaptive(srhs,th,ta,tb,atol,rtol,0.5)
    if(!fin(sres$y)) break
    th<-sres$y; sav[m+1,]<-th; horizon<-tb
  }
  list(theta=sav, full_evals=env$fe, cheap_evals=ce, horizon=horizon,
       wall_ms=as.numeric(Sys.time()-t0,units="secs")*1000)
}

# ============================================================================
p_probe<-seed_patch(scen[[1]])
cat(sprintf("Model %s: seeded stand = %d cohorts, patch ode_size = %d (5 soil + 4 aux + %d cohort states). Window %d d.\n",
    MODEL, length(stand_h), p_probe$ode_size, p_probe$ode_size-9, Tend))
# faithfulness check
{ si<-soil_idx(p_probe); y<-p_probe$ode_state; d0<-p_probe$derivs(y,0)
  U<-uptake_from(y[si],d0[si],0,scen[[1]])
  chk<-max(abs(soil_rhs(y[si],0,U,scen[[1]])-d0[si]))
  cat(sprintf("cheap soil-RHS vs real patch derivs at t=0: max|diff| = %.2e\n\n", chk)) }

cat("Soil integrator on the real coupled patch, cohorts frozen (the slow block).\n")
cat("full(glob) = expensive full-patch RHS evals (one per soil-limited RK stage, as plant's\n")
cat("single-step-size solver pays); full(MRI) = expensive evals (one per daily macro);\n")
cat("cheap = soil-only RHS evals; error = MRI vs global soil trajectory (daily grid).\n\n")
cat("Two MRI variants: freeze = cohort demand frozen per macro day (naive Lie split);\n")
cat("resp = soil-moisture-responsive demand (probe uptake vs theta at macro start).\n\n")
cat(sprintf("%-9s %7s | %10s %10s | %8s %8s %8s | %8s %8s\n",
    "scenario","mm/yr","err_freeze","err_resp","full_g","full_frz","full_rsp",
    "cut_frz","cut_rsp"))
res<-list()
for(sn in names(scen)){
  series<-scen[[sn]]
  g <-run_global   (series, 1e-8,1e-8)
  rf<-run_mri      (series, 1e-8,1e-8)
  rr<-run_mri_resp (series, 1e-8,1e-8)
  ef<-max(abs(rf$theta-g$theta),na.rm=TRUE); er<-max(abs(rr$theta-g$theta),na.rm=TRUE)
  cf<-g$full_evals/max(rf$full_evals,1); cr<-g$full_evals/max(rr$full_evals,1)
  cat(sprintf("%-9s %7.0f | %10.2e %10.2e | %8d %8d %8d | %7.0fx %7.0fx\n",
      sn, sum(series), ef, er, g$full_evals, rf$full_evals, rr$full_evals, cf, cr)); flush(stdout())
  res[[sn]]<-list(g=g,rf=rf,rr=rr,ef=ef,er=er)
}
saveRDS(list(model=MODEL,Tend=Tend,scen=scen,res=res), file.path(here,sprintf("data/bench_real_%s.rds",MODEL)))
cat(sprintf("\nwrote data/bench_real_%s.rds\n", MODEL))
