# Can we truncate the IBM at t=3.5?  Everything we need is at ages <= 3, and the
# stored runs go to 105.32 -- most of the cost is the mature canopy.  Check that a
# truncated run with the same seed reproduces the stored trajectory exactly, and
# measure the per-area cost of the truncated run.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
zs <- c(0, 1, 5, 10)

arrivals <- function(max_time, rate, area, delta_t = 0.1) {
  t0 <- seq(0, max_time - delta_t, by = delta_t)
  n  <- rpois(length(t0), delta_t * rate * area)
  sort(unlist(mapply(function(a, k) runif(k, a, a + delta_t), t0, n)))
}

ibm_run <- function(p, area, seed, MPL) {
  set.seed(seed); p$patch_area <- area; p$max_patch_lifetime <- MPL
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, Environment("TF24"), Control())
  sc  <- plant:::NodeSchedule(1); sc$max_time <- MPL
  sc$set_times(arrivals(MPL, p$strategies[[1]]$birth_rate_y, area), 1)
  obj$node_schedule <- sc
  tm <- c(); nal <- c(); ncum <- c(); la <- matrix(NA_real_, 0, length(zs))
  snap <- function() {
    sp <- obj$patch$species[[1]]
    tm  <<- c(tm, obj$patch$time)
    nal <<- c(nal, sp$size / area)
    ncum<<- c(ncum, sp$size_individuals / area)
    la  <<- rbind(la, vapply(zs, function(z) sp$compute_competition(z) / area, 0))
  }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm)
  list(time=tm[ok], n=nal[ok], ncum=ncum[ok], la=la[ok,,drop=FALSE])
}

p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
cat("birth_rate_y =", p$strategies[[1]]$birth_rate_y, "\n")
cat("max_patch_lifetime (default) =", p$max_patch_lifetime, "\n\n")

o <- readRDS("probes/out/oracle-ibm.rds")
AGES <- c(1,1.5,2,2.5,3)
grid <- o$grid; ji <- vapply(AGES, function(a) which.min(abs(grid-a)), 1L)

cat("=== truncation reproducibility: area 4, seeds 4001..4003, MPL=3.5 vs stored MPL=105.32 ===\n")
for (k in 1:3) {
  t0 <- Sys.time()
  r <- ibm_run(p, 4, 1000*4+k, 3.5)
  el <- as.numeric(difftime(Sys.time(), t0, units="secs"))
  new <- approx(r$time, r$la[,1], AGES, rule=2)$y
  old <- o$out[["4"]]$L[k, ji, 1]
  cat(sprintf("seed %d (%.1fs): new %s\n              old %s   maxreldiff %.2e\n",
      1000*4+k, el, paste(sprintf("%.6f", new), collapse=" "),
      paste(sprintf("%.6f", old), collapse=" "), max(abs(new/old-1))))
}

cat("\n=== truncated cost by area (1 rep each, MPL=3.5) ===\n")
for (A in c(4, 16, 64, 128, 256)) {
  t0 <- Sys.time(); r <- ibm_run(p, A, 999000+A, 3.5)
  el <- as.numeric(difftime(Sys.time(), t0, units="secs"))
  cat(sprintf("area %-5g  %7.2fs   nsteps=%-5d  Nc(3)=%.3f  L(3)=%.4f\n",
      A, el, length(r$time), approx(r$time,r$ncum,3,rule=2)$y,
      approx(r$time,r$la[,1],3,rule=2)$y))
  flush.console()
}
