# The soil chain alone, with no root uptake, on a record's rainfall, under the
# SCM's Cash-Karp controller with the record's knots as step targets: its steps,
# rejections and binding layer, and the moisture at each step's start.
# VAR=theta integrates each layer's moisture as TF24 does; VAR=u integrates
# u = theta^(1 - q), in which a layer draining with nothing above it moves
# linearly in time. The error is measured in theta either way.
#
#   PLANT_LIB=... [REGIME=long-drought] [TOL=3e-5] [VAR=theta] [CONTROL=odelia] \
#     [REF=chain.rds] [OUT=chain.rds] Rscript harness/soil_chain.R
#
# CONTROL picks the step-size law after an accepted step: odelia's (below);
# shrink, the same factor floored at 0.2 instead of 1; or pi, shrink with the
# previous ratio's term at beta = 0.04. REF, another run's OUT on the same
# record, reports this run's moisture error at each knot against it.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
tab <- new.env()
sys.source(file.path(here, "ark436.R"), envir = tab)
regime <- Sys.getenv("REGIME", SCEN)
tol <- as.numeric(Sys.getenv("TOL", "3e-5"))
atol <- 1e-4 * tol
VAR <- match.arg(Sys.getenv("VAR", "theta"), c("theta", "u"))
CONTROL <- match.arg(Sys.getenv("CONTROL", "odelia"), c("odelia", "shrink", "pi"))
env <- mkenv(regime)
knots <- sort(unique(active_knots(regime)))
rain_at <- function(t) max(0, env$extrinsic_drivers_evaluate_range("rainfall", t))
# TF24_Environment::compute_rates with no uptake, as harness/ark_prototype.R has it.
theta_s <- 0.428; K_sat <- 163.0411; q <- 2 * 6.57 + 3; b_inf <- 8; dz <- 1.5 / 5
rates_theta <- function(th, t) {
  out <- K_sat * (pmin(pmax(th, 0), theta_s) / theta_s)^q
  (c(rain_at(t) * max(0, 1 - (th[1] / theta_s)^b_inf), out[-5]) - out) / dz
}
to_theta <- function(y) if (VAR == "u") y^(1 / (1 - q)) else y
rates <- function(y, t) {
  th <- to_theta(y)
  d <- rates_theta(th, t)
  if (VAR == "u") (1 - q) * th^(-q) * d else d
}
step <- function(y, t, h, k1) {
  k <- vector("list", 6)
  k[[1]] <- k1
  for (i in 2:6) {
    yi <- y
    for (j in 1:(i - 1)) if (tab$ACK[i, j] != 0) yi <- yi + h * tab$ACK[i, j] * k[[j]]
    k[[i]] <- rates(yi, t + tab$cCK[i] * h)
  }
  y1 <- y
  e <- 0
  for (i in 1:6) {
    y1 <- y1 + h * tab$bCK[i] * k[[i]]
    e <- e + h * (tab$bCK[i] - tab$dCK[i]) * k[[i]]
  }
  list(y = y1, e = e)
}

# OdeControl's rules: accept at a ratio of 1.1, grow by at most 5 and never
# shrink after an accepted step, and a step clipped to its target keeps the
# proposal it carried. A step at the minimum size is accepted whatever its ratio.
y <- rep(0.214, 5)
if (VAR == "u") y <- y^(1 - q)
t <- 0
h <- 1e-6
n_rej <- 0
r_prev <- 1
out <- list()
k1 <- rates(y, t)
for (target in c(knots[knots > 0 & knots < LIFETIME], LIFETIME)) {
  while (t < target - 1e-14) {
    final <- t + h >= target - 1e-12 * max(1, target)
    hh <- if (final) target - t else h
    s <- step(y, t, hh, k1)
    th1 <- to_theta(s$y)
    e_th <- if (VAR == "u") abs(th1 * s$e / ((1 - q) * s$y)) else abs(s$e)
    ratio <- e_th / (tol * abs(th1) + atol)
    r <- max(ratio)
    if (!is.finite(r)) r <- 1e10
    if (r > 1.1 && hh > 1e-6 * (1 + 1e-9)) {
      n_rej <- n_rej + 1
      h <- max(hh * max(0.2, 0.9 / r^(1 / 5)), 1e-6)
      next
    }
    out[[length(out) + 1]] <- c(t, hh, r, which.max(ratio), to_theta(y))
    t <- if (final) target else t + hh
    y <- s$y
    k1 <- rates(y, t)
    fac <- switch(CONTROL,
                  odelia = min(5, max(1, 0.9 / max(r, 1e-300)^(1 / 6))),
                  shrink = min(5, max(0.2, 0.9 / max(r, 1e-300)^(1 / 5))),
                  pi = min(5, max(0.2, 0.9 * max(r, 1e-300)^(-(0.2 - 0.75 * 0.04)) * r_prev^0.04)))
    r_prev <- max(r, 1e-4)
    if (!final) h <- min(hh * fac, 5)
  }
}
rows <- do.call(rbind, out)
colnames(rows) <- c("t0", "h", "ratio", "layer", paste0("theta_", 1:5))
DAY <- 1 / 365
wet <- vapply(rows[, "t0"] + rows[, "h"] / 2, rain_at, 0) > 0
# h |lambda| / beta at each step's start in theta, beta being Cash-Karp's real
# stability boundary: the chain's Jacobian is lower bidiagonal, so its
# eigenvalues are its diagonal.
th <- pmin(pmax(rows[, paste0("theta_", 1:5), drop = FALSE], 0), theta_s)
diag <- K_sat * q * th^(q - 1) / theta_s^q / dz
diag[, 1] <- diag[, 1] + vapply(rows[, "t0"], rain_at, 0) * b_inf * th[, 1]^(b_inf - 1) / theta_s^b_inf / dz
stiff <- rows[, "h"] * apply(diag, 1, max) / 3.7343596
cat(sprintf("%s, %s, tol %g: %d accepted, %d rejected (%.1f%%) | on rain intervals %d, dry %d | binding layer 1-5: %s | final theta %s%s\n",
            regime, VAR, tol, nrow(rows), n_rej, 100 * n_rej / (nrow(rows) + n_rej), sum(wet), sum(!wet),
            paste(tabulate(rows[, "layer"], 5), collapse = "/"), paste(signif(to_theta(y), 4), collapse = " "),
            if (VAR == "theta") sprintf(" | h |lambda| / beta at the start >= 0.8: %.1f%%, > 1: %.1f%%",
                                        100 * mean(stiff >= 0.8), 100 * mean(stiff > 1)) else ""))
if (nzchar(Sys.getenv("REF"))) {
  ref <- readRDS(Sys.getenv("REF"))
  at <- intersect(rows[, "t0"], ref$rows[, "t0"][ref$rows[, "t0"] %in% knots])
  cols <- paste0("theta_", 1:5)
  err <- abs(rows[match(at, rows[, "t0"]), cols] / ref$rows[match(at, ref$rows[, "t0"]), cols] - 1)
  cat(sprintf("  moisture against %s: at %d knots, relative error median %.2g, 99%% %.2g, max %.2g; at the end, max %.2g\n",
              basename(Sys.getenv("REF")), length(at), if (length(at)) median(err) else NA,
              if (length(at)) quantile(err, 0.99) else NA, if (length(at)) max(err) else NA,
              max(abs(to_theta(y) / ref$y - 1))))
}
if (nzchar(Sys.getenv("OUT"))) saveRDS(list(rows = rows, rejected = n_rej, wet = wet, y = to_theta(y), VAR = VAR,
                                            tol = tol, regime = regime), Sys.getenv("OUT"))
