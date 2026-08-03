# Truncation done right: draw the arrival process over the FULL 105.32 y (same RNG
# consumption as probes/12-oracle.R) but only hand the runner the arrivals at or
# before TEND and stop there.  Then the stored seeds must reproduce exactly.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
zs <- c(0, 1, 5, 10); MPL <- 105.32; TEND <- 3.5

arrivals <- function(max_time, rate, area, delta_t = 0.1) {
  t0 <- seq(0, max_time - delta_t, by = delta_t)
  n  <- rpois(length(t0), delta_t * rate * area)
  sort(unlist(mapply(function(a, k) runif(k, a, a + delta_t), t0, n)))
}

ibm_run <- function(p, area, seed, tend) {
  set.seed(seed); p$patch_area <- area; p$max_patch_lifetime <- tend
  aa <- arrivals(MPL, p$strategies[[1]]$birth_rate_y, area)   # full-length stream
  aa <- aa[aa <= tend]
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, Environment("TF24"), Control())
  sc  <- plant:::NodeSchedule(1); sc$max_time <- tend
  sc$set_times(aa, 1)
  obj$node_schedule <- sc
  tm <- c(); nal <- c(); ncum <- c(); la <- matrix(NA_real_, 0, length(zs))
  snap <- function() {
    sp <- obj$patch$species[[1]]
    tm  <<- c(tm, obj$patch$time); nal <<- c(nal, sp$size / area)
    ncum<<- c(ncum, sp$size_individuals / area)
    la  <<- rbind(la, vapply(zs, function(z) sp$compute_competition(z) / area, 0))
  }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm)
  list(time=tm[ok], n=nal[ok], ncum=ncum[ok], la=la[ok,,drop=FALSE], arr=aa)
}

p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
o <- readRDS("probes/out/oracle-ibm.rds")
AGES <- c(1,1.5,2,2.5,3); grid <- o$grid
ji <- vapply(AGES, function(a) which.min(abs(grid-a)), 1L)

cat("=== exact reproduction of stored seeds, truncated at", TEND, "===\n")
for (spec in list(list(4, 1:4), list(16, 1:3), list(64, 1:2))) {
  A <- spec[[1]]
  for (k in spec[[2]]) {
    t0 <- Sys.time(); r <- ibm_run(p, A, 1000*A+k, TEND)
    el <- as.numeric(difftime(Sys.time(), t0, units="secs"))
    new <- approx(r$time, r$la[,1], AGES, rule=2)$y
    old <- o$out[[as.character(A)]]$L[k, ji, 1]
    ncn <- approx(r$time, r$ncum, AGES, rule=2)$y
    nco <- o$out[[as.character(A)]]$Nc[k, ji]
    cat(sprintf("A=%-4g k=%d %6.2fs  maxreldiff(L)=%.3e  maxdiff(Nc)=%.3e  narr<=3=%d Nc(3)=%.2f\n",
        A, k, el, max(abs(new/old-1)), max(abs(ncn-nco)),
        sum(r$arr <= 3), ncn[5]*A))
    flush.console()
  }
}

cat("\n=== cost + spread pilot (truncated), fresh seeds ===\n")
set.seed(1)
for (A in c(4, 16, 64, 128, 256)) {
  nrep <- if (A <= 16) 12 else if (A == 64) 5 else if (A == 128) 3 else 2
  t0 <- Sys.time()
  L3 <- numeric(nrep); Nc3 <- numeric(nrep)
  for (k in seq_len(nrep)) {
    r <- ibm_run(p, A, 7000000 + 1000*A + k, TEND)
    L3[k] <- approx(r$time, r$la[,1], 3, rule=2)$y
    Nc3[k]<- approx(r$time, r$ncum, 3, rule=2)$y
  }
  el <- as.numeric(difftime(Sys.time(), t0, units="secs"))
  cat(sprintf("A=%-5g nrep=%-3d %8.2fs (%7.3f s/rep)  L(3) mean=%.4f sd=%.4f  sd*sqrt(A)=%.3f  Nc(3) mean=%.3f\n",
      A, nrep, el, el/nrep, mean(L3), sd(L3), sd(L3)*sqrt(A), mean(Nc3)))
  flush.console()
}
