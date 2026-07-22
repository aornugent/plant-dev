# Path-A falsifier (the speed arbitrage): can total water uptake be CHEAPLY
# refreshed as soil water moves over a weekly macro-step? The arbitrage advances
# cohorts on a weekly step while soil water sub-cycles; it needs uptake a(u) to be
# a low-order function of soil water u over that excursion. It dies if a curves too
# fast -- especially near the dry limit, where response is 50-291x hypersensitive
# (the same reason freezing a plateaus at ~10% error).
#
# Cheap test, existing machinery only: one resident run records uptake a*(t) (per
# layer) and its soil trajectory u*(t)=sweep_soil(a*). Within each weekly window the
# cohort population barely changes (slow block), so a's variation there is almost
# all due to u moving. Per layer, per window, fit uptake_l ~ poly(u_l) at degree 1
# and 2; the relative residual is how far uptake departs from a cheap Taylor refresh.
#   small residual (incl. dry windows) -> cheap refresh viable -> build Newton-on-uptake
#   large residual in dry windows       -> refresh fails near the dry limit -> arbitrage
#                                          dies as its ancestors did; pivot.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant", export_all=TRUE, quiet=TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
CACHE <- control(ode_method="rkck", ode_tol_rel=1e-6, ode_tol_abs=1e-6, save_RK45_cache=TRUE)
jobs <- list(intense_storms=12, extended_drought=20)   # storms (big du) + dry (hypersensitive)
WIN_YEARS <- 1/52                                       # weekly windows

NSOIL <- 5                                              # physical soil layers (aux vars follow)
relresid <- function(x, y, deg) {                       # relative residual of poly(y~x,deg)
  ok <- is.finite(x) & is.finite(y); x <- x[ok]; y <- y[ok]
  if (length(unique(x)) <= deg + 1) return(NA)
  fit <- tryCatch(lm(y ~ poly(x, deg, raw=TRUE)), error=function(e) NULL)
  if (is.null(fit)) return(NA)
  rng <- diff(range(y)); if (rng <= 0) return(0)
  sqrt(mean(residuals(fit)^2)) / rng
}

for (nm in names(jobs)) {
  years <- jobs[[nm]]
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years*365)); rain <- b$rain[seq_len(nd)]
  times <- (0:(nd-1))/365; tmax <- max(times)
  mkenv <- function(){ e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  mkp <- function(){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
    add_strategies(p, trait_matrix(0.0825,"lma"), birth_rate=1) }
  scm <- run_scm(mkp(), mkenv(), CACHE); st <- scm$ode_times
  scm$set_record_uptake(TRUE); scm$run_mutant(mkp())
  at <- scm$uptake_times; aM <- do.call(rbind, scm$uptake_values)   # times x (>=5)
  a_st <- lapply(st, function(tt) aM[which.min(abs(at - tt)), ])
  aS <- do.call(rbind, a_st)                                        # aligned to st
  uS <- do.call(rbind, scm$sweep_soil(st, a_st, st))               # times x (5 soil + aux)
  nlay <- min(NSOIL, ncol(uS), ncol(aS))                           # physical soil layers only
  uS <- uS[, seq_len(nlay), drop=FALSE]; aS <- aS[, seq_len(nlay), drop=FALSE]
  umin <- min(uS)                                                   # proxy for the dry floor
  cat(sprintf("\n== %s (%dyr): %d steps, %d layers, soil range [%.3f, %.3f] ==\n",
              nm, years, length(st), nlay, umin, max(uS))); flush(stdout())

  edges <- seq(0, tmax, by = WIN_YEARS); nb <- length(edges)-1
  # per window: driest-layer wetness, and worst-over-layers relative residual (deg 1 & 2)
  r1 <- r2 <- wet <- du <- rep(NA, nb)
  for (w in seq_len(nb)) {
    sel <- st >= edges[w] & st < edges[w+1]
    if (sum(sel) < 4) next
    wet[w] <- min(uS[sel, ])                                        # driest layer this window
    perlay1 <- perlay2 <- pdu <- rep(NA, nlay)
    for (l in seq_len(nlay)) { perlay1[l] <- relresid(uS[sel,l], aS[sel,l], 1)
      perlay2[l] <- relresid(uS[sel,l], aS[sel,l], 2); pdu[l] <- diff(range(uS[sel,l])) }
    r1[w] <- max(perlay1, na.rm=TRUE); r2[w] <- max(perlay2, na.rm=TRUE); du[w] <- max(pdu, na.rm=TRUE)
  }
  ok <- is.finite(r2)
  # split windows by wetness tercile: is the fit worse in the driest windows?
  q <- quantile(wet[ok], c(1/3, 2/3), na.rm=TRUE)
  dry <- ok & wet <= q[1]; mid <- ok & wet > q[1] & wet <= q[2]; wetq <- ok & wet > q[2]
  ssum <- function(v) sprintf("med=%.3f p90=%.3f max=%.3f", median(v,na.rm=TRUE), quantile(v,.9,na.rm=TRUE), max(v,na.rm=TRUE))
  cat(sprintf("  windows=%d  weekly du(driest) med=%.4f\n", sum(ok), median(du[ok],na.rm=TRUE)))
  cat(sprintf("  linear    resid ALL: %s\n", ssum(r1[ok])))
  cat(sprintf("  quadratic resid ALL: %s\n", ssum(r2[ok])))
  cat(sprintf("  quadratic resid DRY tercile: %s\n", ssum(r2[dry])))
  cat(sprintf("  quadratic resid WET tercile: %s\n", ssum(r2[wetq]))); flush(stdout())
  saveRDS(list(r1=r1,r2=r2,wet=wet,du=du,edges=edges), file.path(outdir, paste0("uptake_taylor_", nm, ".rds")))
}
cat("ALLDONE\n")
