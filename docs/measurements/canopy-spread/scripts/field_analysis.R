# Crown-mean light at the top crowns of two field_snap.R runs at matching times,
# under each numerical layer between the node quadrature and the crown:
#   model    QK21 over the 65-knot spline (what plant computes)
#   spline   a fine quadrature over the spline (the crown rule removed)
#   lumped   a fine quadrature over exp(-A), A from the nodes (spline removed)
#   spread   as lumped, every panel spread over its members' heights (comb removed)
#   noself   as lumped, without the crown's own panel
#   selfspr  as lumped, only the crown's own panel spread
# For each: m, the crown-mean openness, and dm/dln h, its response to the crown's
# own height in the fixed field (the channel an invader's trait acts through).
# Usage: Rscript field_analysis.R coarse.rds fine.rds   (needs plant for QK21)
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb/scripts/field_lib.R")
f <- commandArgs(TRUE)
xa <- readRDS(f[1]); xb <- readRDS(f[2])
qk <- plant:::QK(21L)

hermite <- function(K) {
  x <- K[, "height"]; y <- K[, "light_availability"]; m <- K[, "slope"]; top <- max(x)
  function(z) vapply(z, function(zz) {
    if (zz > top) return(1)
    k <- min(max(findInterval(zz, x), 1), length(x) - 1)
    d <- x[k + 1] - x[k]; t <- (zz - x[k]) / d
    v <- (2 * t^3 - 3 * t^2 + 1) * y[k] + (t^3 - 2 * t^2 + t) * d * m[k] +
      (-2 * t^3 + 3 * t^2) * y[k + 1] + (t^3 - t^2) * d * m[k + 1]
    max(0, v)
  }, 0)
}
schemes <- function(s, j) {
  Es <- hermite(s$knots)
  list(spline = Es,
       lumped = function(z) exp(-field_A(s, z)),
       spread = function(z) exp(-field_A(s, z, M = 8)),
       noself = function(z) exp(-field_A(s, z, skip = j)),
       selfspr = function(z) exp(-field_A(s, z, spread_only = j, Ms = 8)))
}
model_mean <- function(Efun, h, eta) {
  x <- qk$integrate_vector_x(0, h)
  qk$integrate_vector(pmax(Efun(x), 1e-4) * qf(x, h, eta), 0, h)
}
measure <- function(s, j) {
  h <- s$height[j]; sc <- schemes(s, j); d <- 1e-4
  one <- function(mean_fun, E) {
    m <- mean_fun(E, h, s$eta)
    c(m = m, dm = (mean_fun(E, h * exp(d), s$eta) - mean_fun(E, h * exp(-d), s$eta)) / (2 * d))
  }
  rbind(model = one(model_mean, sc$spline),
        t(vapply(sc, function(E) one(crown_mean, E), c(m = 0, dm = 0))))
}
for (i in seq_along(xa$snaps)) {
  a <- xa$snaps[[i]]; b <- xb$snaps[[i]]
  if (abs(a$time - b$time) > 1e-9) { cat("times differ\n"); next }
  cat(sprintf("\n== t = %.4f: top %.2f m, A at 0 %.3f (coarse) %.3f (fine); light at the top crown's base %.3f\n",
              a$time, max(a$height), a$A[1], b$A[1], exp(-a$A[1])))
  for (bd in head(a$birth[-length(a$birth)], 2)) {
    ja <- which.min(abs(a$birth - bd)); jb <- which.min(abs(b$birth - bd))
    ma <- measure(a, ja); mb <- measure(b, jb)
    x_a <- (a$height[ja] - a$height[ja + 1]) / (a$height[ja] / a$eta)
    cat(sprintf("  node born %.4f: h %.3f, overlap ratio to next %.2f (coarse) %.2f (fine)\n", bd, a$height[ja], x_a,
                (b$height[jb] - b$height[jb + 1]) / (b$height[jb] / b$eta)))
    out <- cbind(m_coarse = ma[, "m"], m_fine = mb[, "m"], m_move = mb[, "m"] - ma[, "m"],
                 dm_coarse = ma[, "dm"], dm_fine = mb[, "dm"], dm_move = mb[, "dm"] - ma[, "dm"])
    print(signif(out, 5))
  }
}
