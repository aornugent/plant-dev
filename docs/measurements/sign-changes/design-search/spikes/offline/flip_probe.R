# What the sub-step trigger saw where it flipped: node i's net production at the
# step's seven readings and on its dense output at u = k/64, the trigger's margin,
# and the sub-stepped end less the plain end for the node.
# Usage: Rscript flip_probe.R <ln_theta> <step> <node>
args <- commandArgs(TRUE)
x <- as.numeric(args[1]); s_at <- as.integer(args[2]); i <- as.integer(args[3])
source("toy.R")
mesh <- adaptive_mesh(1e-4, 1)
for (dx in c(-1e-12, 1e-12)) {
  th <- exp(x + dx)
  at <- replay(mesh, th, "sub", 3, stop_at = s_at)
  y <- at$y; t0 <- at$t; h <- at$h
  st <- ck_step(function(z, c) rates(z, t0 + c * h, th), y, h)
  yend <- st$y; kend <- rates(yend, t0 + h, th)
  rd <- c(vapply(1:6, function(j) P_of(st$stages[[j]][i], st$stages[[j]][iW], th, i), 0),
          P_of(yend[i], yend[iW], th, i))
  s0 <- if (rd[1] < 0) -1 else 1
  margin <- min(s0 * rd) - 0.02 * (max(rd) - min(rd))
  kv <- c(vapply(st$k, `[`, 0, i), kend[i]); kW_v <- c(vapply(st$k, `[`, 0, iW), kend[iW])
  u <- seq(0, 1, length.out = 65)
  Mu <- y[i] + h * as.vector(dense_w(u) %*% kv); Wu <- y[iW] + h * as.vector(dense_w(u) %*% kW_v)
  Pu <- P_of(Mu, Wu, th, i)
  z <- y[blk(i)]; hs <- h / 3
  for (q in 0:2) z <- ck_step(function(zz, c) node_rates(zz[1], y[iW] + h * as.vector(dense_w((q + c) / 3) %*% kW_v), th, i), z, hs)$y
  cat(sprintf("ln theta %+.3e: h %.4g, readings %s\n  trigger margin %.3e (on if <= 0); dense-output P min %.4g max %.4g, sign changes %d\n  sub-stepped minus plain end: M %.3e F %.3e (relative %.2e)\n",
              x + dx, h, paste(signif(rd, 4), collapse = " "), margin, min(Pu), max(Pu),
              sum(diff(sign(Pu)) != 0), z[1] - yend[i], z[2] - yend[N + i], (z[2] - yend[N + i]) / yend[N + i]))
}
