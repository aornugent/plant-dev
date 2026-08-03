# Close the loop.  StochasticPatch omits environment.ode_size() from its ODE
# system, so TF24's soil water never leaves its initial 0.214 while the SCM
# integrates it to the rainfall equilibrium 0.310613.  Hand the stochastic
# runner an environment already at that equilibrium and see whether the
# SCM/IBM gap disappears.
source("probes/lib.R"); setwd("/home/user/plant-dev")
MPL <- 105.32; TEND <- 3.5; AGES <- c(1, 1.5, 2, 2.5, 3)
p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
s1 <- p0$strategies[[1]]
SW <- 0.310613

mkenv <- function(wet) {
  e <- Environment("TF24")
  if (wet) e$set_soil_water_state(rep(SW, length(e$get_soil_water_state())))
  e
}

run_reg <- function(area, seed, wet, offset = 0.5) {
  set.seed(seed); p <- p0; p$patch_area <- area; p$max_patch_lifetime <- TEND
  dt <- 1/area; aa <- seq(offset*dt, TEND, by = dt)
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, mkenv(wet), Control())
  sc <- plant:::NodeSchedule(1); sc$max_time <- TEND; sc$set_times(aa, 1)
  obj$node_schedule <- sc
  tm <- c(); la <- c()
  snap <- function() { sp <- obj$patch$species[[1]]
    tm <<- c(tm, obj$patch$time); la <<- c(la, sp$compute_competition(0)/area) }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  sw <- obj$patch$environment$get_soil_water_state()
  ok <- !duplicated(tm)
  list(L = approx(tm[ok], la[ok], AGES, rule=2)$y, sw = sw)
}

arrivals <- function(max_time, rate, area, delta_t = 0.1) {
  t0 <- seq(0, max_time - delta_t, by = delta_t)
  n  <- rpois(length(t0), delta_t * rate * area)
  sort(unlist(mapply(function(a, k) runif(k, a, a + delta_t), t0, n)))
}
run_stoch <- function(area, seed, wet) {
  set.seed(seed); p <- p0; p$patch_area <- area; p$max_patch_lifetime <- TEND
  aa <- arrivals(MPL, 1, area); aa <- aa[aa <= TEND]
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, mkenv(wet), Control())
  sc <- plant:::NodeSchedule(1); sc$max_time <- TEND; sc$set_times(aa, 1)
  obj$node_schedule <- sc
  tm <- c(); la <- c()
  snap <- function() { sp <- obj$patch$species[[1]]
    tm <<- c(tm, obj$patch$time); la <<- c(la, sp$compute_competition(0)/area) }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm); approx(tm[ok], la[ok], AGES, rule=2)$y
}

ex <- readRDS("probes/out/excess-scm.rds")
scm561 <- ex$scm[["561"]][match(AGES, ex$ages)]
cat(sprintf("%-30s %s\n", "SCM birth-date (n=561)", paste(sprintf("%10.6f", scm561), collapse=" ")))

cat("\n=== regular arrivals, dry (as shipped) vs soil pre-set to the SCM equilibrium ===\n")
for (wet in c(FALSE, TRUE)) for (A in c(32, 64, 128)) {
  ns <- if (A == 128) 2 else 3
  rr <- lapply(seq_len(ns), function(k) run_reg(A, 6660000+1000*A+k, wet))
  LL <- t(vapply(rr, `[[`, numeric(length(AGES)), "L"))
  cat(sprintf("%-8s A=%-5g %s   ratio SCM/IBM %s  soil=%.4f\n",
      if (wet) "wet" else "dry", A, paste(sprintf("%10.6f", colMeans(LL)), collapse=" "),
      paste(sprintf("%6.3f", scm561/colMeans(LL)), collapse=" "), rr[[1]]$sw[1]))
  flush.console()
}

cat("\n=== Poisson-arrival ensembles, wet, A=16 (R=120) and A=4 (R=250) ===\n")
library(parallel)
for (sp2 in list(c(4,250), c(16,120))) {
  A <- sp2[1]; R <- sp2[2]
  LL <- do.call(rbind, mclapply(seq_len(R), function(k)
          run_stoch(A, 8880000+10000*A+k, TRUE), mc.cores = 1))
  m <- colMeans(LL); se <- apply(LL,2,sd)/sqrt(R)
  cat(sprintf("wet A=%-4g R=%-4d %s\n           se %s\n           ratio SCM/IBM %s\n",
      A, R, paste(sprintf("%10.6f", m), collapse=" "),
      paste(sprintf("%10.6f", se), collapse=" "),
      paste(sprintf("%10.4f", scm561/m), collapse=" ")))
  flush.console()
}
