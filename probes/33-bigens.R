# Step 2: large truncated ensembles at several patch areas, to fit
#   excess(A) = b + c/A
# and read off b, the extrapolated infinite-patch excess.  Truncating the IBM at
# t=3.5 reproduces the stored ages<=3 trajectories bit-for-bit (probes/32) at
# ~1/100 the cost, which is what makes the replicate counts affordable.
#
# Each replicate also records the arrival-time moments
#   m_p = (1/A) sum_i (t - s_i)^p ,  E[m_p] = lambda t^(p+1)/(p+1)  (lambda = 1)
# which are exact-mean control variates for the ensemble mean of L.
suppressMessages(library(plant)); library(parallel); setwd("/home/user/plant-dev")
MPL <- 105.32; TEND <- 3.5; AGES <- c(1, 1.5, 2, 2.5, 3); PMAX <- 3

arrivals <- function(max_time, rate, area, delta_t = 0.1) {
  t0 <- seq(0, max_time - delta_t, by = delta_t)
  n  <- rpois(length(t0), delta_t * rate * area)
  sort(unlist(mapply(function(a, k) runif(k, a, a + delta_t), t0, n)))
}

one_rep <- function(p, area, seed) {
  set.seed(seed); p$patch_area <- area; p$max_patch_lifetime <- TEND
  aa <- arrivals(MPL, p$strategies[[1]]$birth_rate_y, area)
  aa <- aa[aa <= TEND]
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, Environment("TF24"), Control())
  sc  <- plant:::NodeSchedule(1); sc$max_time <- TEND; sc$set_times(aa, 1)
  obj$node_schedule <- sc
  tm <- c(); nal <- c(); ncum <- c(); la <- c()
  snap <- function() {
    sp <- obj$patch$species[[1]]
    tm  <<- c(tm, obj$patch$time); nal <<- c(nal, sp$size / area)
    ncum<<- c(ncum, sp$size_individuals / area)
    la  <<- c(la, sp$compute_competition(0) / area)
  }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm)
  # exact arrival-time moments at each age
  M <- t(vapply(AGES, function(tt) { u <- tt - aa[aa <= tt]
         vapply(0:PMAX, function(pp) sum(u^pp)/area, 0) }, numeric(PMAX+1)))
  list(L  = approx(tm[ok], la[ok],   AGES, rule=2)$y,
       Nc = approx(tm[ok], ncum[ok], AGES, rule=2)$y,
       N  = approx(tm[ok], nal[ok],  AGES, rule=2)$y,
       M  = M, nsnap = sum(ok))
}

p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))

spec <- list(c(4, 600), c(16, 400), c(64, 150), c(128, 60))
res <- list()
for (s in spec) {
  A <- s[1]; R <- s[2]
  seeds <- 7000000L + 10000L*as.integer(A) + seq_len(R)
  t0 <- Sys.time()
  rr <- mclapply(seeds, function(sd) tryCatch(one_rep(p, A, sd), error=function(e) NULL),
                 mc.cores = 2, mc.preschedule = FALSE)
  bad <- vapply(rr, is.null, TRUE)
  rr <- rr[!bad]
  el <- as.numeric(difftime(Sys.time(), t0, units="secs"))
  L  <- do.call(rbind, lapply(rr, `[[`, "L"))
  Nc <- do.call(rbind, lapply(rr, `[[`, "Nc"))
  N  <- do.call(rbind, lapply(rr, `[[`, "N"))
  M  <- array(unlist(lapply(rr, `[[`, "M")), c(length(AGES), PMAX+1, length(rr)))
  M  <- aperm(M, c(3,1,2))   # rep x age x moment
  res[[as.character(A)]] <- list(area=A, R=nrow(L), L=L, Nc=Nc, N=N, M=M,
                                 secs=el, nfail=sum(bad))
  cat(sprintf("A=%-5g R=%-4d %8.1fs (%7.3f s/rep, wall w/2 cores)  fail=%d  L(3) mean=%.5f sd=%.5f se=%.5f  Nc(3) mean=%.4f\n",
      A, nrow(L), el, el/nrow(L), sum(bad), mean(L[,5]), sd(L[,5]), sd(L[,5])/sqrt(nrow(L)),
      mean(Nc[,5])))
  flush.console()
  saveRDS(list(res=res, ages=AGES, pmax=PMAX, tend=TEND), "probes/out/bigens.rds")
}
cat("done\n")
