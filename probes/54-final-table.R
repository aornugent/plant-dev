# The paper table: leaf area above ground at ages 1..3 for the soil-corrected
# individual-based oracle vs both SCM coordinates.
#
# Snapshot artefact: the IBM can only be observed at introduction events.  With
# REGULAR arrivals at spacing dt = 1/(lambda*A) and offset = 1.0*dt the arrival
# times are k/A, so every target age (1, 1.5, 2, 2.5, 3) is an exact multiple of
# dt for A = 64 and A = 128 and is hit exactly -- no interpolation whatsoever.
# offset = 0.5*dt (midpoint quadrature, 2nd order) is also run for comparison; it
# needs interpolation, whose relative error for a locally exponential L is
# (k*dt)^2/8 with k = dlnL/dt ~ 4-6 /y, i.e. <0.08% at A=64 and <0.02% at A=128
# (vs ~20-70% at A=4, which is why 4 m2 is excluded).
#
# Soil water: StochasticPatch never integrates it.  The SCM's own trajectory is
# 0.214 -> 0.310613 by t=0.19, falling to 0.29922 by t=3.  Freezing the oracle at
# each end brackets the answer.
suppressMessages(library(plant)); library(parallel)
source("probes/lib.R"); setwd("/home/user/plant-dev")
MPL <- 105.32; TEND <- 3.5; AGES <- c(1, 1.5, 2, 2.5, 3); PMAX <- 3
SOIL <- c(wet = 0.310613, dry = 0.299220)   # SCM plateau; SCM value at t=3
p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
tt0 <- p0$node_schedule_times[[1]]
mid <- function(x) sort(unique(c(x, (head(x,-1)+tail(x,-1))/2)))

## ---------------- SCM, both coordinates ----------------------------
scm_lai <- function(bd, tt) {
  p <- p0; p$max_patch_lifetime <- TEND; p$node_schedule_times <- list(tt[tt <= TEND])
  ct <- Control(); ct$node_density_in_birth_date <- bd
  scm <- scm_collect(p, "TF24", ct)
  tm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
  la <- vapply(seq_along(scm$history), function(k)
    scm$history[[k]]$species[[1]]$compute_competition(0), 0)
  vapply(AGES, function(a) la[which.min(abs(tm - a))], 0)
}
cat("=== SCM, schedule truncated at 3.5 (verified bit-exact vs the full run) ===\n")
S <- list()
for (bd in c(FALSE, TRUE)) for (lev in 0:2) {
  tt <- tt0; if (lev >= 1) tt <- mid(tt); if (lev >= 2) tt <- mid(tt)
  key <- paste0(if (bd) "bd" else "ht", "_", sum(tt <= TEND))
  S[[key]] <- scm_lai(bd, tt)
  cat(sprintf("%-6s n<=3.5=%-4d %s\n", if (bd) "birth" else "height",
      sum(tt <= TEND), paste(sprintf("%11.6f", S[[key]]), collapse=" "))); flush.console()
}

## ---------------- oracle ------------------------------------------
mkenv <- function(sw) { e <- Environment("TF24")
  e$set_soil_water_state(rep(sw, length(e$get_soil_water_state()))); e }
arrivals <- function(rate, area, delta_t = 0.1) {
  t0 <- seq(0, MPL - delta_t, by = delta_t)
  n  <- rpois(length(t0), delta_t * rate * area)
  sort(unlist(mapply(function(a, k) runif(k, a, a + delta_t), t0, n)))
}
run_ibm <- function(area, seed, sw, aa) {
  set.seed(seed); p <- p0; p$patch_area <- area; p$max_patch_lifetime <- TEND
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, mkenv(sw), Control())
  sc <- plant:::NodeSchedule(1); sc$max_time <- TEND; sc$set_times(aa, 1)
  obj$node_schedule <- sc
  tm <- c(); la <- c()
  snap <- function() { sp <- obj$patch$species[[1]]
    tm <<- c(tm, obj$patch$time); la <<- c(la, sp$compute_competition(0)/area) }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm)
  M <- t(vapply(AGES, function(t2) { u <- t2 - aa[aa <= t2]
        vapply(0:PMAX, function(q) sum(u^q)/area, 0) }, numeric(PMAX+1)))
  list(L = approx(tm[ok], la[ok], AGES, rule=2)$y, M = M,
       hit = vapply(AGES, function(a) min(abs(tm[ok]-a)), 0))
}
reg <- function(area, off) { dt <- 1/area; seq(off*dt, TEND, by = dt) }

cat("\n=== oracle: regular arrivals, soil frozen at each end of the bracket ===\n")
O <- list()
for (A in c(64, 128)) for (off in if (A == 64) c(1.0, 0.5) else 1.0)
  for (sn in names(SOIL)) {
    ns <- if (A == 128) 2 else 3
    rr <- lapply(seq_len(ns), function(k) run_ibm(A, 7770000+1000*A+k, SOIL[[sn]], reg(A, off)))
    L <- t(vapply(rr, `[[`, numeric(5), "L")); m <- colMeans(L)
    key <- sprintf("A%d_off%.1f_%s", A, off, sn); O[[key]] <- m
    cat(sprintf("A=%-4g off=%.1f soil=%-3s %s  se %s  max|t-age|=%.1e\n", A, off, sn,
        paste(sprintf("%11.6f", m), collapse=" "),
        paste(sprintf("%.1e", apply(L,2,sd)/sqrt(ns)), collapse=" "),
        max(rr[[1]]$hit))); flush.console()
  }

cat("\n=== oracle: Poisson arrivals, A=64, soil=wet, R=40 (control-variate adjusted) ===\n")
R <- 40
rr <- mclapply(seq_len(R), function(k) run_ibm(64, 9990000+k, SOIL[["wet"]], {
        set.seed(9990000+k); a <- arrivals(1, 64); a[a <= TEND] }), mc.cores = 2)
rr <- rr[!vapply(rr, is.null, TRUE)]
Lp <- t(vapply(rr, `[[`, numeric(5), "L"))
Mp <- array(unlist(lapply(rr, `[[`, "M")), c(5, PMAX+1, length(rr))); Mp <- aperm(Mp, c(3,1,2))
mu <- function(t2) vapply(0:PMAX, function(q) t2^(q+1)/(q+1), 0)
pcv <- pse <- numeric(5)
for (i in 1:5) { d <- sweep(Mp[,i,,drop=TRUE], 2, mu(AGES[i]), "-")
  f <- lm(Lp[,i] ~ d); b <- coef(f)[-1]; b[is.na(b)] <- 0
  pcv[i] <- mean(Lp[,i]) - sum(b*colMeans(d)); pse[i] <- sd(residuals(f))/sqrt(nrow(Lp)) }
cat(sprintf("plain  %s  se %s\n", paste(sprintf("%11.6f", colMeans(Lp)), collapse=" "),
    paste(sprintf("%.1e", apply(Lp,2,sd)/sqrt(nrow(Lp))), collapse=" ")))
cat(sprintf("cv     %s  se %s\n", paste(sprintf("%11.6f", pcv), collapse=" "),
    paste(sprintf("%.1e", pse), collapse=" ")))
O[["Poisson_A64_wet"]] <- pcv

## ---------------- the table ---------------------------------------
cat("\n\n################ FINAL TABLE ################\n")
ora_w <- O[["A128_off1.0_wet"]]; ora_d <- O[["A128_off1.0_dry"]]
ht <- S[["ht_340"]]; bdv <- S[["bd_340"]]
cat(sprintf("%5s | %11s %11s | %11s %13s | %11s %13s\n","age",
  "oracle wet","oracle dry","SCM height","ratio (w..d)","SCM birthdate","ratio (w..d)"))
for (i in 1:5)
  cat(sprintf("%5.1f | %11.6f %11.6f | %11.6f %5.2f..%-5.2f | %11.6f %5.3f..%-5.3f\n",
      AGES[i], ora_w[i], ora_d[i], ht[i], ht[i]/ora_w[i], ht[i]/ora_d[i],
      bdv[i], bdv[i]/ora_w[i], bdv[i]/ora_d[i]))
cat("\nsoil bracket width as a fraction of the oracle:\n")
cat(sprintf("  %s\n", paste(sprintf("%.1f%%", 100*(ora_d/ora_w - 1)), collapse="  ")))
cat("\nPoisson vs regular at A=64, soil wet:\n")
cat(sprintf("  regular %s\n  Poisson %s\n  ratio   %s\n",
    paste(sprintf("%11.6f", O[["A64_off1.0_wet"]]), collapse=" "),
    paste(sprintf("%11.6f", O[["Poisson_A64_wet"]]), collapse=" "),
    paste(sprintf("%11.4f", O[["Poisson_A64_wet"]]/O[["A64_off1.0_wet"]]), collapse=" ")))
saveRDS(list(S=S, O=O, ages=AGES, soil=SOIL), "probes/out/54-final.rds")
