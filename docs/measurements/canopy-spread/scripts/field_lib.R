# Offline fields from a field_snap.R snapshot: the lumped field as plant builds
# it, the spread field the probe builds, and crown-mean light under each.
Qf <- function(z, h, eta) ifelse(z <= h & h > 0, (1 - pmin(z / h, 1)^eta)^2, 0)
qf <- function(z, h, eta) ifelse(z > 0 & z <= h, 2 * eta * (1 - (z / h)^eta) * (z / h)^eta / z, 0)

# The panels: node j's two half panels (lo toward the taller node j-1, hi toward
# the shorter j+1 or the boundary node), as extinction at height zero.
panels <- function(s) {
  n <- length(s$height)            # nodes plus the boundary node, last
  c_lo <- s$lo * s$scale / s$area  # lo[1] = 0
  c_hi <- s$hi * s$scale / s$area  # hi[n] = 0 (the boundary node has no upper interval)
  h_up <- c(s$height[1], s$height[-n])
  h_dn <- c(s$height[-1], s$height[n])
  data.frame(c_lo = c_lo, c_hi = c_hi, h = s$height, h_up = h_up, h_dn = h_dn)
}
sub_points <- function(M) { lam <- (seq_len(M) - 0.5) / M; list(lam = lam, a = 2 * (1 - lam) / M) }

# A(z) with every panel at its node's height, or spread over M sub-points per half
# panel; `skip` drops panel j, `spread_only` spreads panel j alone.
field_A <- function(s, z, M = 0, skip = 0, spread_only = 0, Ms = 8) {
  pn <- panels(s); A <- numeric(length(z))
  sp <- sub_points(max(M, Ms, 1))
  for (j in seq_len(nrow(pn))) {
    if (j == skip) next
    c <- pn$c_lo[j] + pn$c_hi[j]
    m <- if (j == spread_only) Ms else M
    if (m == 0) { A <- A + c * Qf(z, pn$h[j], s$eta); next }
    spj <- sub_points(m)
    for (k in seq_along(spj$lam)) {
      if (pn$c_lo[j] > 0) A <- A + pn$c_lo[j] * spj$a[k] * Qf(z, pn$h[j] + spj$lam[k] * (pn$h_up[j] - pn$h[j]), s$eta)
      if (pn$c_hi[j] > 0) A <- A + pn$c_hi[j] * spj$a[k] * Qf(z, pn$h[j] + spj$lam[k] * (pn$h_dn[j] - pn$h[j]), s$eta)
    }
  }
  A
}
# Crown-mean openness of a crown of height h in light E(z): integral of
# max(E, 1e-4) q(z, h) over [0, h], on a fine composite Simpson grid.
crown_mean <- function(Efun, h, eta, n = 4000) {
  z <- seq(0, h, length.out = n + 1); w <- rep(c(2, 4), length.out = n + 1); w[1] <- 1; w[n + 1] <- 1
  sum(w * pmax(Efun(z), 1e-4) * qf(z, h, eta)) * h / n / 3
}
