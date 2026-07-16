#!/usr/bin/env Rscript
# E2 — soil-block microscopy (Phase 0 validation, pure double, no tape).
#
# Question (from the soil consult + build plan): is the adaptive step collapse a
# COORDINATE ARTIFACT of integrating theta near its lower bound? Fit the singular
# exponent(s); test whether a desingularizing change of variables removes the
# collapse at matched accuracy; and check whether the drainage envelope K(theta)
# and the potential envelope psi(theta) share ONE envelope (if not, a single
# chart only partly desingularizes).
#
# Faithful to plant/inst/include/plant/models/tf24_environment.h:
#   K(theta)   = K_sat * (theta/theta_sat)^(2 n_psi + 3)      [drainage out]
#   psi(theta) = a_psi * (theta/theta_sat)^(-n_psi) / 1e6 MPa [potential read]
# 5 layers, dz = depth/5, infiltration w/ saturation-excess runoff, residual guard.

## ---- parameters (defaults from the header) --------------------------------
theta_sat <- 0.428; K_sat <- 163.0411; a_psi <- 1.78e3; n_psi <- 6.57
a_infil <- 1; b_infil <- 8; depth <- 1.5; nL <- 5; dz <- depth / nL
theta_res <- 1e-2
p_drain <- 2 * n_psi + 3      # 16.14  (K exponent, vanishes at 0)
p_ret   <- -n_psi             # -6.57  (psi exponent, diverges at 0)

Kf   <- function(th) { t <- pmax(th, 0);            K_sat * (t/theta_sat)^p_drain }
psif <- function(th) { t <- pmax(th, theta_res);    a_psi * (t/theta_sat)^p_ret / 1e6 }
dpsi <- function(th) { t <- pmax(th, theta_res); p_ret * a_psi * (t/theta_sat)^(p_ret-1) / (1e6*theta_sat) }
dKdt <- function(th) { t <- pmax(th, 0);      p_drain * K_sat * (t/theta_sat)^(p_drain-1) / theta_sat }

# CLEAN drawdown: constant light rain so the ONLY hard feature is the layers'
# near-singular approach to the bound. (Kink thrashing is a separate remedy,
# tested at the end.) rain << sink so layers deplete toward theta_res.
rain_const <- 0.05
rainfall   <- function(t) rain_const

# root uptake sink per layer: a steady demand that draws layers to the bound
sink_vec <- c(0.02, 0.05, 0.10, 0.08, 0.05)   # deeper = thirstier

## ---- RHS: 5 soil states + 1 coupling "reader" x (dx/dt = sum psi_i) --------
# x mimics the large block reading the potential; including it in the error norm
# is the N/L amplifier in miniature. run with read_on = FALSE to isolate the soil.
rhs <- function(t, y, read_on = TRUE) {
  th <- y[1:nL]
  rain <- rainfall(t)
  runoff_factor <- 1 - a_infil * (pmax(th[1],0)/theta_sat)^b_infil
  infil <- rain * max(0, runoff_factor)
  out <- Kf(th)
  dth <- numeric(nL)
  for (i in 1:nL) {
    win <- if (i == 1) infil else out[i-1]
    r <- (win - out[i] - sink_vec[i]) / dz
    if (th[i] <= theta_res && r < 0) r <- 0     # positivity guard
    dth[i] <- r
  }
  dx <- if (read_on) sum(psif(th)) else 0
  c(dth, dx)
}

## ---- Dormand-Prince RK45 adaptive stepper (records every accepted step) ----
dp45 <- function(f, y0, t0, t1, atol = 1e-7, rtol = 1e-7, h0 = 1e-4, ...) {
  A <- list(c(),
            c(1/5),
            c(3/40, 9/40),
            c(44/45, -56/15, 32/9),
            c(19372/6561, -25360/2187, 64448/6561, -212/729),
            c(9017/3168, -355/33, 46732/5247, 49/176, -5103/18656),
            c(35/384, 0, 500/1113, 125/192, -2187/6784, 11/84))
  b5 <- c(35/384, 0, 500/1113, 125/192, -2187/6784, 11/84, 0)
  b4 <- c(5179/57600, 0, 7571/16695, 393/640, -92097/339200, 187/2100, 1/40)
  cc <- c(0, 1/5, 3/10, 4/5, 8/9, 1, 1)
  y <- y0; t <- t0; h <- h0; rec <- list(); n_rej <- 0
  while (t < t1 - 1e-14) {
    if (t + h > t1) h <- t1 - t
    k <- vector("list", 7)
    k[[1]] <- f(t, y, ...)
    for (s in 2:7) {
      ys <- y
      for (j in 1:(s-1)) ys <- ys + h * A[[s]][j] * k[[j]]
      k[[s]] <- f(t + cc[s]*h, ys, ...)
    }
    y5 <- y; y4 <- y
    for (s in 1:7) { y5 <- y5 + h*b5[s]*k[[s]]; y4 <- y4 + h*b4[s]*k[[s]] }
    sc  <- atol + rtol * pmax(abs(y), abs(y5))
    err <- sqrt(mean(((y5 - y4)/sc)^2))
    if (!is.finite(err)) { err <- 10 }           # non-finite trial => reject, shrink
    if (err <= 1) {
      t <- t + h; y <- y5
      rec[[length(rec)+1]] <- list(t = t, h = h, y = y, err = err)
      fac <- min(5, max(0.2, 0.9 * err^(-1/5)))
      h <- h * fac
    } else {
      n_rej <- n_rej + 1
      h <- h * min(1, max(0.1, 0.9 * err^(-1/5)))
    }
    if (h < 1e-12) { cat("  !! step underflow at t=", t, "\n"); break }
  }
  list(rec = rec, n_acc = length(rec), n_rej = n_rej, y_end = y)
}

## ---- balance distance d = ||theta - theta*|| / ||theta|| -------------------
# instantaneous balance: K(theta*) = max(0, win - sink). No positive root when
# win - sink < 0  ->  the excursion heads to the bound; use theta_res as theta*.
theta_star <- function(th, t) {
  rain <- rainfall(t)
  infil <- rain * max(0, 1 - a_infil*(pmax(th[1],0)/theta_sat)^b_infil)
  out <- Kf(th); ts <- numeric(nL)
  for (i in 1:nL) {
    win <- if (i == 1) infil else out[i-1]
    target <- win - sink_vec[i]
    ts[i] <- if (target <= 0) theta_res else theta_sat * (target/K_sat)^(1/p_drain)
  }
  ts
}

y0 <- c(rep(theta_sat*0.5, nL), 0)
cat("=== E2 soil-block microscopy ===\n")
cat(sprintf("K exponent %.2f (vanishes), psi exponent %.2f (diverges)\n", p_drain, p_ret))

## ---- (1) baseline: does the collapse reproduce, and is it accuracy-driven? -
for (ro in c(FALSE, TRUE)) {
  r <- dp45(rhs, y0, 0, 1.0, read_on = ro)
  ts <- sapply(r$rec, function(z) z$t); hs <- sapply(r$rec, function(z) z$h)
  d  <- sapply(r$rec, function(z) {
    th <- z$y[1:nL]; ts_ <- theta_star(th, z$t)
    sqrt(sum((th - ts_)^2)) / sqrt(sum(th^2))
  })
  ok <- is.finite(log(hs)) & is.finite(log(d + 1e-12))
  cc <- suppressWarnings(cor(log(hs[ok]), log(d[ok] + 1e-12)))
  cat(sprintf("\nreader %-3s: accepted=%d rejected=%d  corr(log h, log d)=%.2f\n",
              ifelse(ro,"ON","off"), r$n_acc, r$n_rej, cc))
  # where are the smallest steps (by min theta at that step)?
  o <- order(hs)[1:min(10, length(hs))]
  minth <- sapply(r$rec, function(z) min(z$y[1:nL]))
  cat(sprintf("  smallest-step decile: median min(theta)=%.4f, median d=%.2f\n",
              median(minth[o]), median(d[o])))
  cat(sprintf("  all steps:            median min(theta)=%.4f, median d=%.3f\n",
              median(minth), median(d)))
}

## ---- (2) singular-exponent fit + shared-envelope check ---------------------
cat("\n--- envelope fit near the bound ---\n")
thg <- exp(seq(log(theta_res*1.001), log(theta_sat*0.6), length.out = 200))
slope <- function(yv) coef(lm(log(abs(yv)) ~ log(thg - theta_res)))[2]
slope_th <- function(yv) coef(lm(log(abs(yv)) ~ log(thg)))[2]
cat(sprintf("  d psi/d theta ~ theta^%.2f  (fit vs log theta)\n", slope_th(dpsi(thg))))
cat(sprintf("  d K  /d theta ~ theta^%.2f  (fit vs log theta)\n", slope_th(dKdt(thg))))
# ratio of the two envelopes across the range: constant => shared envelope
ratio <- abs(dpsi(thg)) / abs(dKdt(thg))
cat(sprintf("  |dpsi/dK| envelope ratio spans %.2e .. %.2e over theta in [%.3f, %.3f]\n",
            min(ratio), max(ratio), min(thg), max(thg)))
cat(sprintf("  -> ratio varies by %.1f orders of magnitude: envelopes %s\n",
            log10(max(ratio)/min(ratio)),
            ifelse(log10(max(ratio)/min(ratio)) > 1, "DO NOT share (single chart partial)",
                   "share (single chart suffices)")))

## ---- (3) desingularizing coordinate: two candidate charts ------------------
# A chart w = phi(theta) with exponent q: w = (theta/theta_sat)^q. The state
# rate in w is  dw/dt = q (theta/sat)^(q-1)/sat * dtheta/dt  and the read is
# psi ~ w^(-n_psi/q). Test the chart tuned to the READ (q = n_psi: psi becomes
# LINEAR in w) and to DRAINAGE (q chosen so the K-driven state rate is tame).
# If K and psi shared an envelope, one q would tame both; they don't, so watch
# each chart help one subsystem and hurt the other.
run_chart <- function(q, read_on = TRUE) {
  phi     <- function(th) (pmax(th,theta_res)/theta_sat)^q
  phi_inv <- function(w)  pmin(theta_sat * pmax(w, 0)^(1/q), theta_sat * 1.5)
  rhs_w <- function(t, yw, ...) {
    w <- yw[1:nL]; th <- phi_inv(w)
    dth <- rhs(t, c(th, yw[nL+1]), read_on)[1:nL]
    dwdt <- q * (pmax(th,theta_res)/theta_sat)^(q-1) / theta_sat * dth
    c(dwdt, if (read_on) sum(psif(th)) else 0)
  }
  yw0 <- c(phi(y0[1:nL]), 0)
  r <- dp45(rhs_w, yw0, 0, 1.0, read_on = read_on)
  list(n = r$n_acc, rej = r$n_rej, x = r$y_end[nL+1],
       thmin = min(phi_inv(r$y_end[1:nL])))
}
cat("\n--- coordinate test (reader ON, matched tol 1e-7) ---\n")
r_theta <- dp45(rhs, y0, 0, 1.0, read_on = TRUE)
cat(sprintf("  theta-coord (q=1)   : accepted=%d rej=%d  x(1)=%.4f\n",
            r_theta$n_acc, r_theta$n_rej, r_theta$y_end[nL+1]))
for (q in c(n_psi, n_psi + 1, -(n_psi))) {
  rc <- run_chart(q)
  cat(sprintf("  chart q=%+5.2f        : accepted=%d rej=%d  x(1)=%.4f  |dx|=%.2e  %.2fx\n",
              q, rc$n, rc$rej, rc$x, abs(rc$x - r_theta$y_end[nL+1]),
              r_theta$n_acc / rc$n))
}
cat("  (q=+6.57 linearises the psi READ; q=-6.57 tames drainage-driven state)\n")

## ---- (4) kink-splitting: the separate remedy for the recorded inhomogeneity -
# Re-introduce closely-spaced rainfall kinks; compare integrating THROUGH them
# (stepper rediscovers each kink -> rejections) vs restarting the step AT each
# recorded knot (kink-split). Same accuracy, far fewer wasted steps.
cat("\n--- kink-split test (recorded rainfall knots) ---\n")
knots <- seq(0, 1.0, by = 0.05); kv <- rep(c(0.02, 0.4), length.out = length(knots))
rainfall <<- function(t) kv[max(1, findInterval(t, knots))]
r_through <- dp45(rhs, y0, 0, 1.0, read_on = TRUE)
# kink-split: integrate each [knot_i, knot_{i+1}] segment fresh (rain constant within)
seg <- function() {
  y <- y0; nacc <- 0; nrej <- 0
  for (i in 1:(length(knots)-1)) {
    r <- dp45(rhs, y, knots[i], knots[i+1], read_on = TRUE, h0 = 1e-4)
    y <- r$y_end; nacc <- nacc + r$n_acc; nrej <- nrej + r$n_rej
  }
  list(n = nacc, rej = nrej, x = y[nL+1])
}
rs <- seg()
cat(sprintf("  through kinks : accepted=%d rejected=%d  x(1)=%.4f\n",
            r_through$n_acc, r_through$n_rej, r_through$y_end[nL+1]))
cat(sprintf("  kink-split    : accepted=%d rejected=%d  x(1)=%.4f  |dx|=%.2e\n",
            rs$n, rs$rej, rs$x, abs(rs$x - r_through$y_end[nL+1])))
cat(sprintf("  rejection reduction: %.2fx\n", r_through$n_rej / max(1, rs$rej)))
