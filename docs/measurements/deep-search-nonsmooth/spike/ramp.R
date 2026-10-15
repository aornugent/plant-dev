# RKCK fifth-order weights: quadrature error of a transition of width W (in mean steps)
# against a jump's, on steps of random length (uniform in 0.5-1.5 of the mean). Linear ramp,
# and a smooth one (smoothstep 3x^2 - 2x^3, C1 at its ends).
cc <- c(0, 1/5, 3/10, 3/5, 1, 7/8); b <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
shape <- list(linear = function(x) x, smooth = function(x) 3 * x^2 - 2 * x^3)
G <- function(t, t0, W, f) if (W > 0) f(pmin(pmax((t - t0) / W, 0), 1)) else as.numeric(t >= t0)
area <- function(W, f) if (W > 0) W * integrate(f, 0, 1)$value else 0
err <- function(W, f) {
  h <- runif(80, 0.5, 1.5); s <- c(0, cumsum(h)); t0 <- s[41] + runif(1, -3, 3)
  q <- sum(sapply(seq_along(cc), function(i) b[i] * h * G(head(s, -1) + cc[i] * h, t0, W, f)))
  q - (s[81] - t0 - W + area(W, f))
}
set.seed(1)
for (nm in names(shape)) {
  base <- sqrt(mean(replicate(4000, err(0, shape[[nm]]))^2))
  r <- sapply(c(0.1, 0.22, 0.5, 1, 1.5, 2, 3, 5), function(W) sqrt(mean(replicate(4000, err(W, shape[[nm]]))^2)) / base)
  cat(nm, ": W (mean steps) 0.1 0.22 0.5 1 1.5 2 3 5 -> rms error / jump's", sprintf("%.3f", r), "\n")
}
