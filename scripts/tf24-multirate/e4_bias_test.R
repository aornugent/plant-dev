#!/usr/bin/env Rscript
# B3 footgun (Oracle commit-review): does the m-member collocation introduce a GRADIENT-REDUCTION
# BIAS invisible to adjoint-vs-FD? Adjoint=FD certifies the gradient OF THE m-scheme; it does NOT
# certify that grad(m-scheme) -> grad(full-M scheme) as fast as value does. The danger is a
# member-coordinate regime KINK whose crossing moves with u: its quadrature error has an oscillating
# u-derivative, so the gradient converges slower than the value. Test: value-vs-m and gradient-vs-m
# convergence (vs a fine m reference), with a HARD switch vs a SMOOTHED switch (the Oracle's cure a).
suppressMessages(library(odelia)); options(width=115)
inc<-system.file("include",package="odelia"); so<-file.path(system.file("libs",package="odelia"),"odelia.so")
Sys.setenv(PKG_CPPFLAGS=paste0("-I",inc)); Sys.setenv(PKG_LIBS=shQuote(normalizePath(so)))
here<-"/home/user/plant-dev/scripts/tf24-multirate"; Rcpp::sourceCpp(file.path(here,"e4_fast_ad.cpp"))
cat("=== compiled ===\n")
gen_rain<-function(seed,ndays=60,p01b=0.09,p11b=0.38,shape=0.6,scaleb=11,occ=1){set.seed(seed);doy<-(seq_len(ndays)-1)%%365;season<-(1+cos(2*pi*(doy-15)/365))/2;p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ);p11<-pmin(0.95,0.15+p11b*season^1.5);wet<-logical(ndays);for(t in 2:ndays)wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t]);scale<-4+scaleb*season;rain<-numeric(ndays);rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet]);rain[rain<0.1]<-0;round(rain,2)}
rain<-gen_rain(24); pars<-c(1.0,0.8,0.5); T<-30; k<-20; MREF<-512L

conv<-function(gate_on, gate_w, label){
  ref<-e4_grad(rain,pars,MREF,T,k,1e-10,1e-5,gate_on,gate_w); Fref<-ref$F; gref<-ref$grad_rev
  cat(sprintf("\n[%s]  m=%d reference: F=%.6f\n", label, MREF, Fref))
  cat(sprintf("  %6s | %12s %8s | %12s %8s | %10s\n","m","val_err","rate","grad_err","rate","adj_vs_FD"))
  prevV<-NA; prevG<-NA
  for(m in c(8L,16L,32L,64L,128L)){ r<-e4_grad(rain,pars,m,T,k,1e-10,1e-5,gate_on,gate_w)
    ve<-abs(r$F-Fref); ge<-max(abs(r$grad_rev-gref))
    rv<-if(is.na(prevV))NA else log2(prevV/ve); rg<-if(is.na(prevG))NA else log2(prevG/ge)
    cat(sprintf("  %6d | %12.2e %8s | %12.2e %8s | %10.1e\n", m, ve,
        ifelse(is.na(rv),"-",sprintf("%.2f",rv)), ge, ifelse(is.na(rg),"-",sprintf("%.2f",rg)), r$max_abs_err))
    prevV<-ve; prevG<-ge }
}
cat("\n(0) NO kink (smooth coupling): value & gradient should converge together (baseline)")
conv(0, 0.0, "no kink")
cat("\n(1) HARD member-coordinate kink moving with u: gradient expected to lag value (the footgun)")
conv(1, 0.0, "hard kink")
cat("\n(2) SMOOTHED kink (width 0.1 = the Oracle's cure a): gradient convergence restored")
conv(1, 0.1, "smoothed kink")
cat("\nRead: adj_vs_FD stays ~1e-8 throughout (consistency of the m-scheme gradient). If under the HARD\n")
cat("kink grad_err converges slower than val_err (rate lower) while SMOOTHED restores parity, the\n")
cat("reduction-bias footgun is real AND the model-level smoothing cure works.\n")
