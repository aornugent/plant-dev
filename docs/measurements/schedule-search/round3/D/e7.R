# Forward only, pinned: the top layer's theta, the rain, and the linear multiplier
# R(h*mu1) of the RKCK step for the top layer's own mode, at every step in a window.
Sys.setenv(SWEEP = "0", TANGENT = "")
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/D/probe.R")
win <- as.numeric(strsplit(Sys.getenv("SOILWIN", "37.04,37.09"), ",")[[1]])
env <- mkenv(scen)
th_s <- env$soil_moist_sat; Ks <- env$K_sat; npsi <- env$n_psi; ai <- env$a_infil; bi <- env$b_infil
nd <- env$get_soil_number_of_depths(); dz <- env$depth / nd
rows <- scm$store_trajectory()
tt <- vapply(rows, `[[`, 0, "time")
ins <- vapply(rows, function(r) isTRUE(r$insertion), FALSE)
w <- length(rows[[length(rows)]]$state)
th1 <- vapply(rows, function(r) r$state[length(r$state) - 9], 0)
# RKCK Butcher tableau, advancing with the fifth-order weights.
A <- matrix(0, 6, 6)
A[2, 1] <- 1/5; A[3, 1:2] <- c(3/40, 9/40); A[4, 1:3] <- c(0.3, -0.9, 1.2)
A[5, 1:4] <- c(-11/54, 2.5, -70/27, 35/27)
A[6, 1:5] <- c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096)
bw <- c(37/378, 0, 250/621, 125/594, 0, 512/1771); cc <- rowSums(A)
Rz <- function(z) 1 + z * sum(bw * solve(diag(6) - z * A, rep(1, 6)))
rain <- function(t) max(0, env$extrinsic_drivers_evaluate("rainfall", t))
mu1 <- function(th, r) {
  s <- 1 - ai * (th / th_s)^bi
  dinf <- if (s > 0) -r * ai * bi * th^(bi - 1) / th_s^bi else 0
  tc <- min(max(th, 0), th_s)
  dK <- if (th > 0 && th < th_s) Ks * (2 * npsi + 3) * tc^(2 * npsi + 2) / th_s^(2 * npsi + 3) else 0
  (dinf - dK) / dz
}
idx <- which(tt >= win[1] & tt <= win[2] & !ins)
res <- do.call(rbind, lapply(idx, function(k) {
  if (k == 1 || ins[k]) return(NULL)
  h <- tt[k] - tt[k - 1]; t0 <- tt[k - 1]; th <- th1[k - 1]
  r <- rain(t0 + 0.5 * h)
  m <- mu1(th, r)
  data.frame(k = k, t0 = t0, h = h, theta1 = th, share = 1 - ai * (th / th_s)^bi,
             rain = r, mu1 = m, z = h * m, R = Rz(h * m))
}))
out$soilwin <- res; out$soilpars <- c(th_s = th_s, Ks = Ks, npsi = npsi, ai = ai, bi = bi, dz = dz, width = w)
sv()
options(width = 200); print(out$soilpars); print(res, digits = 6)
