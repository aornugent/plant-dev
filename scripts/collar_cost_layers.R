suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })
mk <- function(gss) Leaf(vcmax_25=100, jmax_25=100*167, c=2.04, b=3, psi_crit=5,
  root_c=2.65, root_b=1.29, root_psi_crit=1.29*(log(1/0.05))^(1/2.65), beta2=1, a=0.3,
  curv_fact_elec_trans=0.7, curv_fact_colim=0.99, GSS_tol_abs=gss,
  vulnerability_curve_ncontrol=100, ci_abs_tol=1e-6, ci_niter=1000, g1_TF24=46.32995,
  beta_R_H=3.4e3, beta_R_V=9.4e4)
tm <- function(f, n=4000, reps=7) median(replicate(reps, system.time(for(i in seq_len(n)) f())[["elapsed"]]))/n*1e6
cat(sprintf("%3s %10s %10s %10s %10s\n","L","solve","prep+1ev","search","1 grad"))
for (nl in c(1,2,5,10,20)) {
  l <- mk(1e-3); th <- 0.000157; h <- 5
  l$set_physiology(area_leaf=1.209e-4, mass_root_prop=rep(1/nl,nl), rho=608, a_bio=0.0245,
    PPFD=900, psi_soil=rep(0.169,nl), soil_depth=1.5*seq_len(nl)/nl,
    leaf_specific_conductance_max=1*th/h, atm_vpd=2, ca=40,
    sapwood_volume_per_leaf_area=th*h, leaf_temp=25, atm_o2_kpa=21, atm_kpa=101.3)
  l$find_root_collar_psi(); ps <- -l$root_collar_psi_
  a <- tm(function() l$find_root_collar_psi()); b <- tm(function() l$evaluate_root_collar_psi(ps))
  g <- tm(function() l$dprofit_droot_collar_psi(ps))
  cat(sprintf("%3d %10.3f %10.3f %10.3f %10.3f\n", nl, a, b, a-b, g))
}
# R call overhead floor
l <- mk(1e-3)
cat(sprintf("\nR/RcppR6 call overhead floor (gamma_ field read): %.3f us\n", tm(function() l$gamma_)))
