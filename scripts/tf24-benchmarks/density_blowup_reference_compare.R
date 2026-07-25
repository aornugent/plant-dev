# Apples-to-apples on the ONE crashing trace we can now reference:
# extended_drought completes under rkck when newton_collar_solve=TRUE.
# Compare mri_uptake (same collar solver) against it -- this is the first real
# test of whether mri_uptake's "survival" on stress traces yields a TRUSTWORTHY
# number or whether it steps over a divergence.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("plant", export_all=TRUE, quiet=TRUE)})
cat("loaded\n"); flush(stdout())
b<-readRDS("scripts/tf24-benchmarks/data/extended_drought.rds")
nd<-length(b$rain); t<-(0:(nd-1))/365
mk<-function(){p<-scm_base_parameters("TF24");p$max_patch_lifetime<-max(t)
  add_strategies(p,trait_matrix(0.0825,"lma"),hyperpar=TF24_hyperpar,birth_rate=list(20))}
mke<-function(){e<-Environment("TF24");e$extrinsic_drivers_set_variable("rainfall",t,b$rain);e}
base<-function(newton){c<-control();c$GSS_tol_abs<-1e-12;c$ci_abs_tol<-1e-12
  c$newton_collar_solve<-newton;c}
go<-function(lbl,ctrl){mri_coupling_evals_reset()
  el<-system.time(r<-tryCatch(sum(run_scm(mk(),mke(),ctrl)$offspring_production),
      error=function(e)paste0("ERR:",substr(conditionMessage(e),1,45))))[["elapsed"]]
  cat(sprintf("  %-34s -> %-26s (%.0fs)\n", lbl,
      if(is.numeric(r))sprintf("%.6g",r) else r, el)); flush(stdout()); r}
ref <- go("rkck        newton=TRUE  [REFERENCE]", base(TRUE))
c1<-base(TRUE); c1$ode_method<-"mri_uptake"; c1$compute_uptake_jacobian<-TRUE
c1$n_collocation_nodes<-0; c1$mri_uptake_tol<-1e-2; c1$mri_uptake_nmicro<-40
c1$ode_step_size_max<-7/365
m1 <- go("mri_uptake  newton=TRUE  [matched]", c1)
c2<-c1; c2$newton_collar_solve<-FALSE
m2 <- go("mri_uptake  newton=FALSE [as in bank]", c2)
if (is.numeric(ref)) for (nm in c("matched","bank")) {
  v <- if(nm=="matched") m1 else m2
  if (is.numeric(v)) cat(sprintf("  rel err (%s) vs reference: %.3e   [ratio %.1fx]\n",
      nm, abs(v-ref)/abs(ref), v/ref))
}
cat("ALLDONE\n")
