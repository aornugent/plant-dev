# Ladder item 1, proper: the ghost is a RARE-invasion probe. Sweep probe B's
# establishment (birth_rate) so its co-resident mass fraction spans heavy->rare,
# and check the frozen-field error relJ -> 0 as mass -> 0 (Oracle: error is
# O(mass fraction), vanishes at rho->0).
options(pkg.build_extra_flags=FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant",export_all=TRUE,quiet=TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
b <- readRDS(file.path(datadir,"intense_storms.rds"))
years <- 12; nd <- round(years*365); rain <- b$rain[1:nd]; times<-(0:(nd-1))/365; tmax<-max(times)
mkenv <- function(){e<-Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall",times,rain); e}
base_p <- function(){p<-scm_base_parameters("TF24"); p$max_patch_lifetime<-tmax; p}
CACHE<-control(ode_method="rkck",ode_tol_rel=1e-6,ode_tol_abs=1e-6,save_RK45_cache=TRUE)
PLAIN<-control(ode_method="rkck",ode_tol_rel=1e-6,ode_tol_abs=1e-6)
resident_scm <- function() run_scm(add_strategies(base_p(),trait_matrix(0.0825,"lma"),birth_rate=1), mkenv(), CACHE)

cat(sprintf("%-10s %-12s %-12s %-12s %-10s %-8s\n","br_B","J_ghostB","J_realB","massfrac_B","relJ","n"))
for (br in c(1, 0.1, 0.01, 0.001)) {
  s2 <- resident_scm(); s2$run_mutant(add_strategies(base_p(),trait_matrix(0.09,"lma"),birth_rate=br))
  Jg <- sum(s2$offspring_production); n <- length(s2$patch$species[[1]]$node_times)
  p2 <- add_strategies(add_strategies(base_p(),trait_matrix(0.0825,"lma"),birth_rate=1),
                       trait_matrix(0.09,"lma"),birth_rate=br)
  scm2 <- run_scm(p2, mkenv(), PLAIN)
  Jr <- scm2$offspring_production[2]; mf <- Jr/sum(scm2$offspring_production)
  cat(sprintf("%-10g %-12.4e %-12.4e %-12.4f %-10.3f %-8d\n", br, Jg, Jr, mf, abs(Jg-Jr)/abs(Jr), n)); flush(stdout())
}
cat("ALLDONE\n")
