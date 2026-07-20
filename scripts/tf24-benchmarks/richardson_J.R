# Ladder rungs 2 (Richardson, "free move") and 4-tail (tolerance band).
# Rung 2: J on a NESTED fixed-schedule family {47, 93, 185} (subsample, base,
#   2x-densify -- each a refinement of the previous), same scenario/horizon/tol.
#   Fit J(h) = J* + C h^p on the 3 points -> convergence order p, extrapolated
#   J*, and an error bar for the finest mesh. Stable order => certified J.
# Rung 4-tail: J at the production ODE tol (1e-4) vs 1e-6 on the finest mesh
#   -> is J bit-stable across the 100x band (does production sit at the loose
#   edge, i.e. is time-integration accuracy already free of J)?

options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                     export_all = TRUE, quiet = TRUE)
})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
nm <- "intense_storms"; years <- 10
b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
nd <- min(length(b$rain), round(years * 365))
rain <- b$rain[seq_len(nd)]; times <- (0:(nd - 1)) / 365; tmax <- max(times)
mkenv <- function(){ e <- Environment("TF24")
  e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
mkpars <- function(){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
  add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1) }
densify <- function(t,k){ if(k<=1) return(t); o<-numeric(0)
  for(i in seq_len(length(t)-1)) o<-c(o, seq(t[i],t[i+1],length.out=k+1)[-(k+1)]); c(o,t[length(t)]) }

runJ <- function(sched, tol){
  ctrl <- control(ode_method="rkck", ode_tol_rel=tol, ode_tol_abs=tol)
  scm <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl)
  scm$set_node_schedule_times(list(sched)); scm$run()
  list(J=sum(scm$offspring_production), n=length(scm$patch$species[[1]]$node_times))
}

# base schedule (from one default run)
scm0 <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6))
scm0$run(); base <- scm0$patch$species[[1]]$node_times
coarse <- base[seq(1, length(base), by = 2)]            # ~0.5x, nested below base
fine   <- densify(base, 2)                              # 2x, nested above base
cat(sprintf("family sizes: coarse=%d base=%d fine=%d\n", length(coarse), length(base), length(fine))); flush(stdout())

r1 <- runJ(coarse, 1e-6); cat(sprintf("J(n=%d,tol=1e-6)=%.8e\n", r1$n, r1$J)); flush(stdout())
r2 <- runJ(base,   1e-6); cat(sprintf("J(n=%d,tol=1e-6)=%.8e\n", r2$n, r2$J)); flush(stdout())
r3 <- runJ(fine,   1e-6); cat(sprintf("J(n=%d,tol=1e-6)=%.8e\n", r3$n, r3$J)); flush(stdout())
# tolerance band on the finest mesh
r3loose <- runJ(fine, 1e-4); cat(sprintf("J(n=%d,tol=1e-4)=%.8e\n", r3loose$n, r3loose$J)); flush(stdout())

# Richardson: successive mesh spacings halve (nested doubling). Order from 3 pts:
J1<-r1$J; J2<-r2$J; J3<-r3$J
p_est <- log(abs((J1-J2)/(J2-J3)))/log(2)
Jstar <- J3 + (J3-J2)/(2^p_est - 1)
relerr_fine <- abs(J3 - Jstar)/abs(Jstar)
tolband_rel <- abs(r3loose$J - r3$J)/abs(r3$J)
cat("\n===RESULT===\n")
cat(sprintf("J: coarse=%.6e base=%.6e fine=%.6e\n", J1,J2,J3))
cat(sprintf("estimated convergence order p = %.2f\n", p_est))
cat(sprintf("Richardson-extrapolated J* = %.6e\n", Jstar))
cat(sprintf("rel error of finest mesh vs J* = %.3f\n", relerr_fine))
cat(sprintf("tolerance band (J@1e-4 vs J@1e-6, finest mesh) rel = %.2e\n", tolband_rel))
cat("ALLDONE\n")
