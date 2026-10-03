# The split's field on an ARK4(3)6L[2]SA grid (phase 1a's arkc: METHOD=ark,
# TOL_SOIL=100, soil estimate from the chain alone). On every crossing step, at
# u = 1/4, 1/2, 3/4, each dense output against one ARK step of u h from the
# step's start, in error weights at the step's end: the soil's five layers
# (in the base weights and in the controller's, x TOL_SOIL) and every member
# that does not cross (the light's part). Dense outputs: the cubic Hermite,
# Kennedy & Carpenter's order-3 one (six stages), the C1 order-3 quartics
# BARK3_4_all and BARK3_4_explicit (six stages and f(y1)); and for the soil
# alone, the chain integrated tightly from the step's start against uptake
# linear between the step's ends. The replay is checked against the grid's own
# soil states, bit for bit.
#   PLANT_LIB=... METHOD=ark TOL=3e-5 ATOL=1e-4 TOL_SOIL=100 NODES=108 GRID=arkc.rds OUT=dc.rds \
#     Rscript harness/dense_check_ark.R
GRID <- Sys.getenv("GRID")
OUTF <- Sys.getenv("OUT")
CHAIN_TOL <- 1e-9
Sys.setenv(TF24_DOMAIN_TOL = "1e9")
source("harness/ark_prototype.R")
stopifnot(method == "ark")
grid <- readRDS(GRID)
program <- grid$st

# Kennedy & Carpenter (2003), ARK4(3)6L[2]SA dense output: theta^1..theta^3 rows.
BKC3 <- rbind(
  c(6943876665148/7220017795957, 0, 7640104374378/9702883013639, -20649996744609/7521556579894,
    8854892464581/2390941311638, -11397109935349/6675773540249),
  c(-54480133/30881146, 0, -11436875/14766696, 174696575/18121608, -12120380/966161, 3843/706),
  c(6818779379841/7100303317025, 0, 2173542590792/12501825683035, -31592104683404/5083833661969,
    61146701046299/7138195549469, -17219254887155/4939391667607))
# The C1 order-3 quartics on the six stages and f(y1) (stage0/ark_dense.txt).
BARK3_4_all <- rbind(
  c(1, 0, 0, 0, 0, 0, 0),
  c(-2.827343294263684, 0, 5.0724874678855265, -3.1688856231520588, 0.95398801675956524, -18.443621586103927, 18.413375018874575),
  c(3.2863517691740536, 0, -9.3979391736750504, 9.0600324275414561, -3.0089381574991574, 37.887243172207853, -37.82675003774915),
  c(-1.3010921797486981, 0, 4.5122106463135241, -5.2105815090800629, 1.7797096097445855, -19.193621586103927, 19.413375018874575))
BARK3_4_explicit <- rbind(
  c(1, 0, 0, 0, 0, 0, 0),
  c(-3.4839678255451552, 0, 8.4045134078518569, -9.974721919052044, 7.7343146555992819, 6.8377050543765074, -9.5178433732304448),
  c(4.5996008317369963, 0, -16.061991053607709, 22.671705019341427, -16.569591435178591, -12.675410108753015, 18.03568674646089),
  c(-1.9577167110301694, 0, 7.8442365862798535, -12.016417804980048, 8.5600362485843018, 6.0877050543765074, -8.5178433732304448))
weighted <- function(y0, h, K, B) function(u) y0 + h * as.vector(K %*% as.vector(u^seq_len(nrow(B)) %*% B))

# The chain alone over [t, t + h], uptake linear from a0 to a1 (phase 1a's chain_alone).
chain_alone <- function(th, t, h, a0, a1) {
  f <- function(x, s) {
    r <- stiff_rates(x, rain_at(s)) - (a0 + (a1 - a0) * (s - t) / h) / dz
    r[x <= theta_res & !(r > 0)] <- 0
    r
  }
  s <- t; hs <- h; k1 <- f(th, s); t1 <- t + h
  while (s < t1) {
    final <- s + hs >= t1
    hh <- if (final) t1 - s else hs
    k <- list(k1)
    for (i in 2:6) k[[i]] <- f(combine(th, tab$ACK[i, ], k, hh), s + tab$cCK[i] * hh)
    y1 <- combine(th, tab$bCK, k, hh)
    e <- combine(0, tab$bCK - tab$dCK, k, hh)
    r <- max(abs(e) / (CHAIN_TOL * abs(y1) + 1e-4 * CHAIN_TOL))
    if (!is.finite(r)) r <- 1e10
    if (r > 1.1 && hh > 1e-12) { hs <- hh * max(0.2, 0.9 / r^(1 / 5)); next }
    s <- if (final) t1 else s + hh
    th <- y1; k1 <- f(th, s)
    if (!final) hs <- hh * min(5, max(0.2, 0.9 / max(r, 1e-300)^(1 / 5)))
  }
  th
}

level_of <- function(y, dydt, h) ct$ode_tol_rel * (ct$ode_a_y * abs(y) + ct$ode_a_dydt * abs(h * dydt)) + ct$ode_tol_abs
uptake_of <- function(M) { aux <- patch$ode_aux; stopifnot(length(aux) == 13 * M + 5); tail(aux, 5) }
sv$t <- 0; sv$h_last <- ct$ode_step_size_initial; sv$zone_until <- -Inf; sv$Pdot <- numeric()
rows <- list(); seen <- 0; mismatch <- 0; drift <- 0
kinds <- c("cubic", "kc3", "bark3_all", "bark3_explicit")
t_start <- proc.time()[["elapsed"]]
for (k in seq_along(times)) {
  patch$introduce_new_node(1L, times[k])
  sv$y <- patch$ode_state; sv$dydt <- rates(sv$y, sv$t); sv$P <- production(sv$y); sv$K <- klass(sv$y)
  M <- (length(sv$y) - 10) %/% 9
  a0 <- uptake_of(M)
  t_end <- if (k < length(times)) times[k + 1] else LIFETIME
  for (i in which(program$time > sv$t & program$time <= t_end)) {
    h <- program$h[i]
    a <- attempt(sv$t, sv$y, sv$dydt, h)
    if (is.null(a)) stop(sprintf("a replayed step raised at t = %.17g", sv$t))
    a1 <- uptake_of(M)
    rec <- as.numeric(unlist(program[i, paste0("soil_", 1:5)]))
    if (!identical(as.numeric(a$y[soil(a$y)]), rec)) mismatch <- mismatch + 1
    drift <- max(drift, max(abs(a$y[soil(a$y)] / rec - 1)))
    f <- which(sign(a$P) != sign(sv$P))
    if (length(f)) {
      seen <- seen + 1
      y0 <- sv$y; f0 <- sv$dydt; y1 <- a$y; f1 <- a$rates
      lev <- level_of(y1, f1, h)
      blk <- soil(y0)
      member_i <- setdiff(seq_len(9 * M), as.vector(outer(1:9, 9 * (f - 1), "+")))
      ratio_step <- max(abs(a$yerr) / abs(lev))
      x_soil <- h * lambda_soil(y0, sv$t) / BETA
      K6 <- do.call(cbind, a$k); K7 <- cbind(K6, f1)
      interps <- list(cubic = dense_of(sv$t, y0, f0, a, h, "cubic"), kc3 = weighted(y0, h, K6, BKC3),
                      bark3_all = weighted(y0, h, K7, BARK3_4_all), bark3_explicit = weighted(y0, h, K7, BARK3_4_explicit))
      for (u in c(0.25, 0.5, 0.75)) {
        r <- attempt(sv$t, y0, f0, u * h)
        if (is.null(r)) next
        ch <- chain_alone(y0[blk], sv$t, u * h, a0, a0 + u * (a1 - a0))
        soil_chain <- max(abs(ch - r$y[blk]) / abs(lev[blk]))
        for (kd in kinds) {
          err <- abs(interps[[kd]](u) - r$y) / abs(lev)
          rows[[length(rows) + 1]] <- data.frame(row = i, u = u, kind = kd, h_days = 365 * h, x_soil = x_soil,
            step_ratio = ratio_step, soil = max(err[blk]), members = if (length(member_i)) max(err[member_i]) else 0,
            soil_chain = soil_chain)
        }
      }
    }
    sv$t <- program$time[i]; sv$y <- a$y; sv$dydt <- a$rates; sv$P <- a$P; sv$K <- a$K
    a0 <- a1
  }
}
d <- do.call(rbind, rows)
saveRDS(d, OUTF)
cat(sprintf("ark grid at tol %g (TOL_SOIL %g): %d steps replayed, soil states differing from the grid's %d (largest relative difference %.2g); %d crossing steps; %.0f s\n",
            tol, TOL_SOIL, nrow(program), mismatch, drift, seen, proc.time()[["elapsed"]] - t_start))
x1 <- d[d$kind == "cubic" & d$u == 0.5, ]
cat(sprintf("crossing steps: median h %.3g days; h |lambda_soil| / beta median %.2f, > 1 on %.0f%%; step ratio median %.3g\n",
            median(x1$h_days), median(x1$x_soil), 100 * mean(x1$x_soil > 1), median(x1$step_ratio)))
stiff <- tapply(d$x_soil, d$row, max) > 1
cat("per crossing step, the max over u, in error weights (soil in the base weights; / TOL_SOIL for the controller's):\n")
for (kd in kinds) {
  x <- d[d$kind == kd, ]
  so <- tapply(x$soil, x$row, max); me <- tapply(x$members, x$row, max)
  cat(sprintf("  %-15s members: over 1 on %d of %d, 99%% %.3g, max %.3g | soil: over 1 on %d (stiff steps %d of %d), over TOL_SOIL on %d; 99%% %.3g, max %.3g\n",
              kd, sum(me > 1), length(me), quantile(me, 0.99), max(me), sum(so > 1), sum(so[stiff] > 1), sum(stiff),
              sum(so > TOL_SOIL), quantile(so, 0.99), max(so)))
}
sc <- tapply(d$soil_chain[d$kind == "cubic"], d$row[d$kind == "cubic"], max)
cat(sprintf("  %-15s soil: over 1 on %d (stiff steps %d of %d), over TOL_SOIL on %d; 99%% %.3g, max %.3g\n",
            "chain alone", sum(sc > 1), sum(sc[stiff] > 1), sum(stiff), sum(sc > TOL_SOIL), quantile(sc, 0.99), max(sc)))
