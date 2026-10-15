# One Cash-Karp step of y' = f(y) = -1 + a*max(0, theta - y): the rate is continuous where
# y falls through theta and its slope in y jumps there. As theta moves the switch across
# the step, compare the plain step's map, the map with the switch's quadrature error
# subtracted, and the exact solution; derivatives by central differences of each map.
A <- list(numeric(0), 1/5, c(3/40, 9/40), c(3/10, -9/10, 6/5), c(-11/54, 5/2, -70/27, 35/27),
          c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096))
cc <- c(0, 1/5, 3/10, 3/5, 1, 7/8); b <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
a <- 2; y0 <- 1; h <- 0.5
f <- function(y, th) -1 + a * max(0, th - y)
rk <- function(th) { k <- numeric(6)
  for (i in 1:6) { yi <- y0 + if (i > 1) h * sum(A[[i]] * k[1:(i - 1)]) else 0; k[i] <- f(yi, th) }
  y0 + h * sum(b * k) }
exact <- function(th) { tc <- y0 - th; if (tc >= h) return(y0 - h); tc <- max(tc, 0); s <- h - tc
  th - (1 - exp(-a * s)) / a }
psi <- function(u) sum(b * pmax(cc - u, 0)) - (1 - u)^2 / 2
corrected <- function(th) { u <- (y0 - th) / h; if (u <= 0 || u >= 1) return(rk(th))
  rk(th) - h^2 * a * psi(u) }  # slope jump of (f_new - f_old) in time at the switch: -a*y' = a
d <- 1e-6; D <- function(F, th) (F(th + d) - F(th - d)) / (2 * d)
cat("   u   dRK/dth  dcorr/dth  dexact/dth   |RK-exact|  |corr-exact|\n")
for (u in seq(0.03, 0.97, length.out = 15)) { th <- y0 - u * h
  cat(sprintf("%5.2f %9.5f %9.5f %10.5f   %.2e    %.2e\n", u, D(rk, th), D(corrected, th), D(exact, th),
              abs(rk(th) - exact(th)), abs(corrected(th) - exact(th)))) }
