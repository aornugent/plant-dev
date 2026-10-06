# Toy: does moving the kink's treatment into the model's formulation help?
# A growth state reads the smooth positive part of a production P(t; theta)
# that crosses zero; J = growth at the end. Cash-Karp on a frozen mesh. The
# gradient dJ/dtheta of the discrete map (central differences at 1e-7, the map
# being smooth) is compared across eight mesh nudges (steps x (1 + 0.0167 k),
# k = -3..3, and a quarter-step shift) and against the converged gradient.
# Arms:
#   plain : y' = sigma_eta(P), eta = 1e-4
#   wide  : eta x10, x100, x1000 (a model change)
#   lag   : z' = (P - z)/tau, y' = sigma_eta(z), tau = 0.05 (a model change)
#   cut   : plain, but a step holding a sign change of P integrated in two
#           pieces split at the zero (the incumbent's mechanism)
# Run: Rscript toy_kink.R
A <- rbind(c(0, 0, 0, 0, 0),
           c(1/5, 0, 0, 0, 0),
           c(3/40, 9/40, 0, 0, 0),
           c(3/10, -9/10, 6/5, 0, 0),
           c(-11/54, 5/2, -70/27, 35/27, 0),
           c(1631/55296, 175/512, 575/13824, 44275/110592, 253/4096))
C <- c(0, 1/5, 3/10, 3/5, 1, 7/8)
B <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)

sigma <- function(P, eta) 0.5 * (P + sqrt(P * P + eta * eta))
P_of <- function(t, theta) sin(2 * pi * t) + 0.3 * sin(2 * pi * 3.1 * t + 1) - theta

rk_step <- function(f, t, y, h) {
  k <- vector("list", 6)
  for (i in 1:6) {
    yi <- y
    if (i > 1) for (j in 1:(i - 1)) yi <- yi + h * A[i, j] * k[[j]]
    k[[i]] <- f(t + C[i] * h, yi)
  }
  y + h * (B[1] * k[[1]] + B[3] * k[[3]] + B[4] * k[[4]] + B[6] * k[[6]])
}

run <- function(mesh, theta, model, eta, cut = FALSE, tau = 0.05) {
  if (model == "lag") {
    f <- function(t, y) c(sigma(y[2], eta), (P_of(t, theta) - y[2]) / tau)
    y <- c(0, P_of(0, theta))
  } else {
    f <- function(t, y) sigma(P_of(t, theta), eta)
    y <- 0
  }
  for (n in seq_len(length(mesh) - 1)) {
    t0 <- mesh[n]; t1 <- mesh[n + 1]
    if (cut && sign(P_of(t0, theta)) != sign(P_of(t1, theta))) {
      ts <- uniroot(function(t) P_of(t, theta), c(t0, t1), tol = 1e-15)$root
      y <- rk_step(f, t0, y, ts - t0)
      y <- rk_step(f, ts, y, t1 - ts)
    } else {
      y <- rk_step(f, t0, y, t1 - t0)
    }
  }
  y[1]
}

grad <- function(mesh, theta, model, eta, cut = FALSE, d = 1e-7) {
  (run(mesh, theta + d, model, eta, cut) - run(mesh, theta - d, model, eta, cut)) / (2 * d)
}

Tend <- 6
theta0 <- 0.2

meshes <- function(h) {
  out <- lapply(-3:3, function(k) {
    hk <- h * (1 + 0.05 * k / 3)
    seq(0, Tend, length.out = ceiling(Tend / hk) + 1)
  })
  base <- seq(0, Tend, length.out = ceiling(Tend / h) + 1)
  shifted <- c(0, base[-c(1, length(base))] + 0.25 * h, Tend)
  c(out, list(unique(shifted[shifted <= Tend])))
}

converged <- function(model, eta) grad(seq(0, Tend, length.out = 30001), theta0, model, eta)

arms <- list(list("plain", 1e-4, FALSE), list("plain", 1e-3, FALSE),
             list("plain", 1e-2, FALSE), list("plain", 1e-1, FALSE),
             list("lag", 1e-4, FALSE), list("plain", 1e-4, TRUE))
gstar <- sapply(arms, function(a) converged(a[[1]], a[[2]]))
cat("h, arm, kappa = h |dP/dt| / eta with |dP/dt| ~ 6.3, converged g*, spread = max|g_k - g_0| over 8 nudges, err = max|g_k - g*|\n")
for (h in c(0.04, 0.02, 0.01)) {
  ms <- meshes(h)
  for (i in seq_along(arms)) {
    a <- arms[[i]]
    gs <- sapply(ms, function(m) grad(m, theta0, a[[1]], a[[2]], a[[3]]))
    name <- sprintf("%s eta=%g", if (a[[3]]) "cut" else a[[1]], a[[2]])
    cat(sprintf("%5.2f  %-16s kappa=%8.2g  g*=%+.6f  spread=%.2e  err=%.2e\n",
                h, name, h * 6.3 / a[[2]], gstar[i], max(abs(gs - gs[4])),
                max(abs(gs - gstar[i]))))
  }
}
