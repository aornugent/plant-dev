# The decisive noise-free test.  Replace the Poisson arrival process in the IBM
# with REGULAR arrivals at spacing dt = 1/(lambda*A).  Recruitment stochasticity
# is then gone entirely, so as A -> infinity the IBM converges to the same
# deterministic mean field the SCM claims to solve.  Any residual
#     b = L_SCM - lim_{A->inf} L_regular(A)
# is solver discrepancy, not nonlinear averaging.  Only mortality remains
# stochastic (establishment probability is not applied by the stochastic
# runner), so a few mortality seeds are averaged at each A.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
TEND <- 3.5; AGES <- c(1, 1.5, 2, 2.5, 3)

run_reg <- function(p, area, seed, offset = 0.5) {
  set.seed(seed); p$patch_area <- area; p$max_patch_lifetime <- TEND
  dt <- 1/(p$strategies[[1]]$birth_rate_y * area)
  aa <- seq(offset*dt, TEND, by = dt)
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, Environment("TF24"), Control())
  sc  <- plant:::NodeSchedule(1); sc$max_time <- TEND; sc$set_times(aa, 1)
  obj$node_schedule <- sc
  tm <- c(); la <- c(); nal <- c(); ncum <- c()
  snap <- function() { sp <- obj$patch$species[[1]]
    tm <<- c(tm, obj$patch$time); la <<- c(la, sp$compute_competition(0)/area)
    nal<<- c(nal, sp$size/area); ncum <<- c(ncum, sp$size_individuals/area) }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm)
  list(L = approx(tm[ok], la[ok], AGES, rule=2)$y,
       N = approx(tm[ok], nal[ok], AGES, rule=2)$y,
       Nc= approx(tm[ok], ncum[ok], AGES, rule=2)$y, narr = length(aa))
}

p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
ex <- readRDS("probes/out/excess-scm.rds")
scm561 <- ex$scm[["561"]][match(AGES, ex$ages)]
cat("SCM (n=561):", sprintf("%.6f", scm561), "\n")
cat("SCM (n=141):", sprintf("%.6f", ex$scm[["141"]][match(AGES, ex$ages)]), "\n\n")

spec <- list(c(4,6), c(8,6), c(16,6), c(32,5), c(64,4), c(128,3), c(256,2))
res <- list()
for (off in c(0.5, 1.0)) {
  cat(sprintf("=== regular arrivals, offset = %.1f * dt ===\n", off))
  cat(sprintf("%-6s %-4s %8s | %s | %s\n","area","nsd","secs",
      paste(sprintf("%9s", sprintf("L(%.1f)", AGES)), collapse=" "),
      paste(sprintf("%8s", sprintf("sd%.1f", AGES)), collapse=" ")))
  for (s in spec) {
    A <- s[1]; ns <- s[2]
    t0 <- Sys.time()
    LL <- t(vapply(seq_len(ns), function(k) run_reg(p, A, 5550000+1000*A+k, off)$L,
                   numeric(length(AGES))))
    el <- as.numeric(difftime(Sys.time(), t0, units="secs"))
    res[[paste0(off,"_",A)]] <- list(off=off, area=A, L=LL, secs=el)
    cat(sprintf("%-6g %-4d %8.1f | %s | %s\n", A, ns, el,
        paste(sprintf("%9.6f", colMeans(LL)), collapse=" "),
        paste(sprintf("%8.5f", apply(LL,2,sd)/sqrt(ns)), collapse=" ")))
    flush.console()
    saveRDS(list(res=res, ages=AGES, scm=scm561), "probes/out/regular.rds")
  }
  cat("\n")
}

## Richardson: L_reg(A) = Linf + k/A^q .  Fit on log scale per age.
cat("=== extrapolation of the regular-arrival ladder ===\n")
for (off in c(0.5, 1.0)) {
  keys <- names(res)[vapply(res, function(z) z$off==off, TRUE)]
  A <- vapply(res[keys], `[[`, 0, "area")
  M <- t(vapply(res[keys], function(z) colMeans(z$L), numeric(length(AGES))))
  cat(sprintf("\noffset %.1f\n", off))
  for (ia in seq_along(AGES)) {
    y <- M[, ia]
    d <- diff(y); ordr <- if (length(d) >= 2) log2(abs(head(d,-1)/tail(d,-1))) else NA
    # two-point Richardson using the two largest areas, assuming order q
    q <- if (all(is.finite(ordr))) mean(tail(ordr, 3)) else 1
    n <- length(y)
    Linf <- y[n] + (y[n]-y[n-1])/(2^q - 1)
    cat(sprintf("age %.1f  ladder %s  order~%.2f  Linf=%.6f  SCM=%.6f  b=%+.6f (%+.2f%%)\n",
        AGES[ia], paste(sprintf("%.5f", y), collapse=" "), q, Linf, scm561[ia],
        scm561[ia]-Linf, 100*(scm561[ia]-Linf)/scm561[ia]))
  }
}
