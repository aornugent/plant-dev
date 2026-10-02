# Which term of the chain carries the error of the first-day soil-bound 'other'
# rejections: one Cash-Karp step on the chain alone from the coupled soil state,
# with one term at a time held at its value at the step's start:
#   rain     the rain rate (the forcing's change inside the step);
#   cap      the saturation factor max(0, 1 - (theta1/theta_s)^8);
#   drain    every layer's drainage K(theta), held at K(theta0);
#   lin      every layer's drainage linearised about theta0 (keeps the stiffness,
#            drops the power law's curvature);
#   up_lin   only the drainage INTO the binding layer linearised (its upstream);
#   own_lin  only the binding layer's OWN drainage linearised.
# Also the knot's rain change on the interpolant over the day after it.
#   nice -n 10 Rscript DEV/rej_class/t1_mech.R > DEV/rej_class/t1_mech.txt
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
W <- "/home/user/plant-dev/.claude/worktrees/agent-a4dae3c2572021890"
O <- file.path(D, "rej_class")
Sys.setenv(PLANT_LIB = file.path(D, "lib_v12t"))
source(file.path(W, "harness", "long_drought.R"))
tab <- new.env()
sys.source(file.path(W, "harness", "ark436.R"), envir = tab)
theta_s <- 0.428; K_sat <- 163.0411; q <- 2 * 6.57 + 3; b_inf <- 8; dz <- 1.5 / 5
env <- mkenv("long-drought")
rain_at <- function(t) pmax(0, env$extrinsic_drivers_evaluate_range("rainfall", t))
Kf <- function(th) K_sat * (pmin(pmax(th, 0), theta_s) / theta_s)^q
dKf <- function(th) ifelse(th > 0 & th < theta_s, q * Kf(th) / th, 0)
capf <- function(th1) pmax(0, 1 - (th1 / theta_s)^b_inf)
combine <- function(y, a, k, h) {
  nz <- which(a != 0)
  if (length(nz) == 1L) return(y + (a[nz] * h) * k[[nz]])
  s <- a[nz[1]] * k[[nz[1]]]
  for (m in nz[-1]) s <- s + a[m] * k[[m]]
  y + h * s
}
# One step with variant v; L is each row's binding layer (for up_lin, own_lin).
ck_variant <- function(y0, t0, h, tol, atol, v, L) {
  K0 <- Kf(y0); dK0 <- dKf(y0); rain0 <- rain_at(t0); cap0 <- capf(y0[, 1])
  n <- nrow(y0)
  lin_mask <- matrix(FALSE, n, 5)   # which layers' drainage is linearised
  if (v == "lin") lin_mask[] <- TRUE
  if (v == "own_lin") lin_mask[cbind(1:n, L)] <- TRUE
  if (v == "up_lin") lin_mask[cbind(which(L > 1), L[L > 1] - 1)] <- TRUE
  f <- function(th, t) {
    out <- Kf(th)
    if (v == "drain") out <- K0
    if (any(lin_mask)) out[lin_mask] <- (K0 + dK0 * (th - y0))[lin_mask]
    rain <- if (v == "rain") rain0 else rain_at(t)
    cap <- if (v == "cap") cap0 else capf(th[, 1])
    (cbind(rain * cap, out[, 1:4, drop = FALSE]) - out) / dz
  }
  k <- list(f(y0, t0))
  for (i in 2:6) k[[i]] <- f(combine(y0, tab$ACK[i, ], k, h), t0 + tab$cCK[i] * h)
  y1 <- combine(y0, tab$bCK, k, h)
  e <- combine(0, tab$bCK - tab$dCK, k, h)
  r <- abs(e) / (tol * abs(y1) + atol)
  list(rmax = apply(r, 1, max), rL = r[cbind(1:n, L)], layer = max.col(r, ties.method = "first"))
}
q3 <- function(x, p = c(.1, .5, .9)) paste(signif(quantile(x, p, na.rm = TRUE), 3), collapse = " / ")
DAY <- 1 / 365
variants <- c("full", "rain", "cap", "drain", "lin", "up_lin", "own_lin")
for (name in c("pics_3e-5", "pi_3e-5", "base_3e-5")) {
  x <- readRDS(file.path(O, paste0("t1_", name, ".rds")))
  run <- readRDS(file.path(D, "pi", "runs", paste0(name, ".rds")))
  rain <- run$rain
  ki <- round(x$knot / DAY)
  y_here <- rain[ki + 1]; y_next <- rain[ki + 2]
  x$after <- ifelse(y_here == 0 & y_next > 0, "starts", ifelse(y_here > 0 & y_next == 0, "stops",
                    ifelse(y_next > y_here, "rises", ifelse(y_next < y_here, "falls", "flat"))))
  B <- which(x$rej & x$cls == "other" & x$since > 0.001 & x$since <= 1 & x$part == "soil")
  b <- x[B, ]; p <- x[b$prev, ]
  y0 <- as.matrix(b[, paste0("theta", 1:5)]); yp <- as.matrix(p[, paste0("theta", 1:5)])
  # Use the chain alone's binding layer for the layer-specific variants.
  L <- b$chain_layer; Lp <- L
  cat(sprintf("\n==== %s: %d first-day soil-bound 'other' rejections\n", name, nrow(b)))
  cat("the knot's rain change, by the daily values (analyse.R) and on the interpolant over the day after:\n")
  print(table(daily = b$change, interpolant = b$after))
  cat("binding layer (chain alone) by the interpolant's change:\n")
  print(table(b$after, L))
  cat("the start state, theta of layers 1-3, 10/50/90%:", q3(b$theta1), "|", q3(b$theta2), "|", q3(b$theta3), "\n")
  cat("h|lambda|/beta at the start: rejected", q3(b$x_soil), "| step before", q3(p$x_soil), "\n")
  cat("the binding layer's ratio, each term held (rejected | step before | jump), 10/50/90%:\n")
  base <- ck_variant(y0, b$t0, b$h, 3e-5, 3e-9, "full", L)$rL
  basep <- ck_variant(yp, p$t0, p$h, 3e-5, 3e-9, "full", Lp)$rL
  for (v in variants) {
    s <- ck_variant(y0, b$t0, b$h, 3e-5, 3e-9, v, L)
    sp <- ck_variant(yp, p$t0, p$h, 3e-5, 3e-9, v, Lp)
    cat(sprintf("  %-8s rejected %s (over full: %s) | before %s | jump %s | max ratio > 1.1 on %.1f%%\n", v,
                q3(s$rL), q3(s$rL / base), q3(sp$rL), q3(s$rL / sp$rL), 100 * mean(s$rmax > 1.1)))
  }
  for (kind in c("starts", "rises")) {
    z <- b$after == kind
    if (sum(z) < 5) next
    cat(sprintf("  interpolant '%s' only (%d): held term over full, median:", kind, sum(z)))
    for (v in variants[-1]) cat(sprintf(" %s %.3g", v, median(ck_variant(y0[z, , drop = FALSE], b$t0[z], b$h[z], 3e-5, 3e-9, v, L[z])$rL / base[z])))
    cat("\n")
  }
  saveRDS(b, file.path(O, paste0("t1_rejected_", name, ".rds")))
}
