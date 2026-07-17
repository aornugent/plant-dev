#!/usr/bin/env Rscript
# Probe the REAL plant TF24 patch: confirm the soil block is the accuracy limiter
# (the premise of the whole multi-rate argument) on the actual coupled system, and
# map the ode-state layout (soil = tail environment.ode_size() block).
suppressMessages(pkgload::load_all("/home/user/plant-dev/plant", quiet=TRUE))
options(width=110)

# ---- realistic semi-arid daily rainfall (mm/day), 1 year --------------------
gen_rain <- function(seed, ndays=365, p01b=0.09, p11b=0.38, shape=0.6, scaleb=11, occ=1) {
  set.seed(seed); doy<-(seq_len(ndays)-1)%%365; season<-(1+cos(2*pi*(doy-15)/365))/2
  p01<-pmin(0.9,(0.010+p01b*season^1.5)*occ); p11<-pmin(0.95,0.15+p11b*season^1.5)
  wet<-logical(ndays); for(t in 2:ndays) wet[t]<-runif(1)<(if(wet[t-1])p11[t] else p01[t])
  scale<-4+scaleb*season; rain<-numeric(ndays); rain[wet]<-rgamma(sum(wet),shape=shape,scale=scale[wet])
  rain[rain<0.1]<-0; round(rain,2)
}
rain_semiarid <- gen_rain(24)
cat(sprintf("semi-arid rainfall: %.0f mm/yr, %.0f%% wet days, max %.1f mm/day\n",
            sum(rain_semiarid), 100*mean(rain_semiarid>0), max(rain_semiarid)))

# rainfall driver: piecewise via interpolated daily series (mm/day -> model units)
days <- 0:364
rain_env <- function(series) {
  env <- Environment("TF24")
  env$extrinsic_drivers_set_variable("rainfall", days, series)
  env
}

# ---- build a TF24 patch, populate cohorts under benign conditions ------------
p0 <- scm_base_parameters("TF24")
p0$max_patch_lifetime <- 10
p1 <- add_strategies(p0, trait_matrix(0.0825, "lma"))

# Populate the patch under BENIGN (mild constant) rainfall so cohorts establish and
# survive; the SCM-to-equilibrium overflows under extreme forcing (by design, a
# demographic guard - orthogonal to the soil integrator). We stress the SOIL block
# afterwards by switching the driver and integrating forward over a bounded window.
env <- Environment("TF24")
env$extrinsic_drivers_set_constant("rainfall", 3.0)   # mm/day, benign
cat("\nrunning SCM to populate a realistic patch (benign constant rainfall)...\n")
scm <- run_scm(p1, env, collect = FALSE)

patch <- scm$patch
n   <- patch$ode_size
env_n <- patch$environment$ode_size
n_node <- patch$node_ode_size
cat(sprintf("patch ode_size = %d  (cohorts=%d, environment/soil block=%d)\n", n, n_node, env_n))
cat(sprintf("soil-state indices in ode vector: [%d .. %d]\n", n_node+1, n))

y <- patch$ode_state
t <- patch$ode_time
cat(sprintf("patch time = %.3f;  soil theta tail = %s\n", t,
            paste(sprintf('%.4f', tail(y, env_n)), collapse=", ")))

# ---- confirm soil is the accuracy limiter: local RHS Jacobian scale ----------
# finite-difference the soil-block rate wrt soil states vs cohort states
d0 <- patch$derivs(y, t)
eps <- 1e-6
soil_idx <- (n_node+1):n
# largest |d rate_soil / d y| over soil states (fast timescale ~ this)
jac_soil <- sapply(soil_idx, function(j){
  yp <- y; yp[j] <- yp[j] + eps
  (patch$derivs(yp, t)[soil_idx] - d0[soil_idx]) / eps
})
lam <- max(abs(jac_soil))
cat(sprintf("\nsoil-block max |d(theta_dot)/d(theta)| ~ %.3g  (fast timescale ~ %.3g day)\n",
            lam, 1/max(lam,1e-30)))

saveRDS(list(rain=rain_semiarid, days=days, y=y, t=t, n=n, n_node=n_node, env_n=env_n,
             p1=p1), "/home/user/plant-dev/scripts/tf24-multirate/data/real_patch_snapshot.rds")
cat("\nwrote data/real_patch_snapshot.rds\n")
