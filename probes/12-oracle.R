# The individual-based solver as an external oracle.  size() is the living
# count; size_individuals() is every node ever introduced, so the living stand
# needs the former.  Both solvers divide leaf area by patch area, so the stand
# structures are directly comparable.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
MPL <- 105.32
grid <- seq(0, MPL, by = 0.5)
zs   <- c(0, 1, 5, 10)
qs   <- c(.1, .5, .9)

arrivals <- function(max_time, rate, area, delta_t = 0.1) {
  t0 <- seq(0, max_time - delta_t, by = delta_t)
  n  <- rpois(length(t0), delta_t * rate * area)
  sort(unlist(mapply(function(a, k) runif(k, a, a + delta_t), t0, n)))
}

ibm_run <- function(p, area, seed) {
  set.seed(seed); p$patch_area <- area; p$max_patch_lifetime <- MPL
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, Environment("TF24"), Control())
  sc  <- plant:::NodeSchedule(1); sc$max_time <- MPL
  sc$set_times(arrivals(MPL, p$strategies[[1]]$birth_rate_y, area), 1)
  obj$node_schedule <- sc
  tm <- c(); nal <- c(); ncum <- c(); la <- matrix(NA_real_, 0, length(zs))
  hm <- c(); hq <- matrix(NA_real_, 0, length(qs))
  snap <- function() {
    sp <- obj$patch$species[[1]]
    tm  <<- c(tm, obj$patch$time)
    nal <<- c(nal, sp$size / area)
    ncum<<- c(ncum, sp$size_individuals / area)
    la  <<- rbind(la, vapply(zs, function(z) sp$compute_competition(z) / area, 0))
    hh  <- sp$heights
    hm  <<- c(hm, if (length(hh)) max(hh) else NA_real_)
    hq  <<- rbind(hq, if (length(hh)) unname(quantile(hh, qs)) else rep(NA_real_, length(qs)))
  }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm)
  list(time=tm[ok], n=nal[ok], ncum=ncum[ok], la=la[ok,,drop=FALSE],
       hmax=hm[ok], hq=hq[ok,,drop=FALSE])
}
interp <- function(x, y) approx(x, y, grid, rule = 2)$y

p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
out <- list()
for (pp in list(list(4,8), list(16,6), list(64,2))) {
  area <- pp[[1]]; nrep <- pp[[2]]
  N <- Nc <- H <- matrix(NA_real_, nrep, length(grid))
  L <- array(NA_real_, c(nrep, length(grid), length(zs)))
  Q <- array(NA_real_, c(nrep, length(grid), length(qs)))
  t0 <- Sys.time()
  for (k in seq_len(nrep)) {
    r <- ibm_run(p, area, 1000*area + k)
    N[k,] <- interp(r$time, r$n); Nc[k,] <- interp(r$time, r$ncum)
    H[k,] <- interp(r$time, r$hmax)
    for (j in seq_along(zs)) L[k,,j] <- interp(r$time, r$la[,j])
    for (j in seq_along(qs)) Q[k,,j] <- interp(r$time, r$hq[,j])
  }
  out[[as.character(area)]] <- list(N=N, Nc=Nc, L=L, H=H, Q=Q, area=area, nrep=nrep)
  j50 <- which.min(abs(grid-50)); j100 <- which.min(abs(grid-100))
  cat(sprintf("area=%-4g reps=%-3d %5.0fs  alive/m2 t=50: %6.3f  t=100: %6.3f  cum recruits/m2 t=100: %6.2f  LAI t=50: %.3f\n",
      area, nrep, as.numeric(difftime(Sys.time(), t0, units="secs")),
      mean(N[,j50]), mean(N[,j100]), mean(Nc[,j100]), mean(L[,j50,1])))
  flush.console()
}
saveRDS(list(out=out, grid=grid, zs=zs, qs=qs), "probes/out/oracle-ibm.rds")
