# Does T6 Slice 1 (newton_collar_solve) rescue the #550 density blow-up?
# plant#551 (closed as NOT PLANNED) names the root cause: opt_psi_stem jumps
# discontinuously in height under drought -> g inherits the jump -> FD dg/dh
# explodes -> the SCM density characteristic overflows. Slice 1 replaces the
# derivative-free bracketing argmax with a safeguarded root-find on the exact
# optimality condition dprofit_droot_collar_psi==0 -- i.e. it directly targets
# that operating-point discontinuity. Never tested against the crashing traces.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("plant", export_all=TRUE, quiet=TRUE)})
cat("loaded\n"); flush(stdout())
dd <- "scripts/tf24-benchmarks/data"
run <- function(nm, newton){
  b<-readRDS(file.path(dd,paste0(nm,".rds"))); nd<-length(b$rain); t<-(0:(nd-1))/365
  ctrl<-control(); ctrl$GSS_tol_abs<-1e-12; ctrl$ci_abs_tol<-1e-12
  ctrl$newton_collar_solve <- newton
  mk<-function(){p<-scm_base_parameters("TF24");p$max_patch_lifetime<-max(t)
    add_strategies(p,trait_matrix(0.0825,"lma"),hyperpar=TF24_hyperpar,birth_rate=list(20))}
  mke<-function(){e<-Environment("TF24");e$extrinsic_drivers_set_variable("rainfall",t,b$rain);e}
  el<-system.time(r<-tryCatch(sum(run_scm(mk(),mke(),ctrl)$offspring_production),
        error=function(e) paste0("ERR:", substr(conditionMessage(e),1,60))))[["elapsed"]]
  cat(sprintf("  %-18s newton=%-5s -> %-30s (%.0fs)\n", nm, newton,
      if(is.numeric(r)) sprintf("%.6g",r) else r, el)); flush(stdout())
  r
}
for (nm in c("whiplash","extended_drought","long_horizon")) {
  run(nm, FALSE); run(nm, TRUE)
}
cat("ALLDONE\n")
