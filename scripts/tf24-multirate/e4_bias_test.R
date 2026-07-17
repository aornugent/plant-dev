#!/usr/bin/env Rscript
# B3 footgun (Oracle commit-review): does the m-member collocation introduce a GRADIENT-REDUCTION
# BIAS invisible to adjoint-vs-FD? adj=FD certifies the gradient OF the m-scheme; it does NOT certify
# grad(m-scheme) -> grad(full-M) as fast as value. The danger is a member-coordinate regime KINK whose
# crossing moves with u: its quadrature error has an oscillating u-derivative. Test value-vs-m and
# gradient-vs-m convergence (vs a fine-m reference), HARD switch vs SMOOTHED (the Oracle's cure a).
suppressMessages(library(odelia)); options(width=115)
inc<-system.file("include",package="odelia"); so<-file.path(system.file("libs",package="odelia"),"odelia.so")
Sys.setenv(PKG_CPPFLAGS=paste0("-I",inc)); Sys.setenv(PKG_LIBS=shQuote(normalizePath(so)))
here<-"/home/user/plant-dev/scripts/tf24-multirate"; Rcpp::sourceCpp(file.path(here,"e4_fast_ad.cpp"))
cat("=== compiled ===\n")
gen_rain<-function(seed,ndays=60,p01b=0.09,p11b=0.38,shape=0.6,scaleb=11,occ=1){set.seed(seed);doy<-(seq_len(ndays)-1)%%365;season<-(1+cos(2*pi*(doy-15)/365))/2;p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ);p11<-pmin(0.95,0.15+p11b*season^1.5);wet<-logical(ndays);for(t in 2:ndays)wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t]);scale<-4+scaleb*season;rain<-numeric(ndays);rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet]);rain[rain<0.1]<-0;round(rain,2)}
rain<-gen_rain(24); pars<-c(1.0,0.8,0.5); T<-20; k<-20; MREF<-128L
conv<-function(gate_on,gate_w,label){ ref<-e4_grad(rain,pars,MREF,T,k,1e-9,1e-5,gate_on,gate_w); Fref<-ref$F; gref<-ref$grad_rev
  cat(sprintf("\n[%s] m=%d ref F=%.6f\n  %5s | %11s %6s | %11s %6s | %9s\n",label,MREF,Fref,"m","val_err","rate","grad_err","rate","adj_vsFD"))
  pV<-NA;pG<-NA; for(m in c(8L,16L,32L,64L)){ r<-e4_grad(rain,pars,m,T,k,1e-9,1e-5,gate_on,gate_w)
    ve<-abs(r$F-Fref); ge<-max(abs(r$grad_rev-gref)); rv<-if(is.na(pV))NA else log2(pV/ve); rg<-if(is.na(pG))NA else log2(pG/ge)
    cat(sprintf("  %5d | %11.2e %6s | %11.2e %6s | %9.1e\n",m,ve,ifelse(is.na(rv),"-",sprintf("%.2f",rv)),ge,ifelse(is.na(rg),"-",sprintf("%.2f",rg)),r$max_abs_err)); pV<-ve;pG<-ge } }
conv(0,0.0,"no kink"); conv(1,0.0,"HARD kink"); conv(1,0.1,"SMOOTHED kink w=0.1")
cat("\nadj_vsFD ~1e-8 => the m-scheme gradient is self-consistent; a HARD moving kink instead breaks it\n")
cat("(non-differentiable crossing) and biases grad-vs-m; SMOOTHING the switch restores both.\n")
