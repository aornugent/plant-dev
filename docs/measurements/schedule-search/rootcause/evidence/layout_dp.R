# layout_dp.R: layout D' (every pilot edge a breakpoint, opening and closing; a09's rho0;
# each spell panel's interval count rounded up to even so the alternate drop merges every
# interval; gap panels hold no node). Nodes and rows against layout D and E6 committed.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
layout_Dp <- function(cs, s = 1, p = pilot_of(cs), px = pilot_run(cs), h = alg$hfun_of(p)) { ea <- edges_all(cs, px)
  br <- sort(unique(c(0, ea$b, H))); g <- seq(0, H, length.out = 40001); dg <- diff(g)[1]; gm <- g[-1] - dg / 2
  open <- p$shut(gm) < 0.5; capv <- vapply(gm, function(b) if (b < p$b1) p$b1 / 12 else if (b < 20) 100 / 365 else 280 / 365, 0)
  rho <- ifelse(open, 1 / pmin(vapply(gm, h, 0), capv), 0); S <- c(); ni <- c()
  for (i in seq_len(length(br) - 1)) { a <- br[i]; b <- br[i + 1]; k <- gm >= a & gm < b; S <- c(S, a)
    if (!any(open[k])) next; m <- s * sum(rho[k]) * dg; n <- 2 * ceiling(m / 2 - 1e-9); ni <- c(ni, n - 1)
    cw <- c(0, cumsum(rho[k] * dg)); u <- c(a, gm[k] + dg / 2)
    S <- c(S, approx(cw / tail(cw, 1), u, seq(0, 1, length.out = n + 1)[2:n], ties = "ordered")$y) }
  list(S = sort(unique(round(S, 10))), n_interior = ni) }
for (cs in BANK) { px <- pilot_run(cs); st <- px$times; Dp <- layout_Dp(cs); D <- readRDS(file.path(SC, "evidence", sprintf("layoutD_%s.rds", cs))); e6 <- E6_c(cs)
  cat(sprintf("%-13s D' %3d nodes (rows %.2f x E6), D %3d (%.2f), E6 %3d | spell panels %3d, with one interior node %3d\n", cs, length(Dp$S), rows_model(Dp$S, st) / rows_model(e6, st),
    length(D$S), rows_model(D$S, st) / rows_model(e6, st), length(e6), length(Dp$n_interior), sum(Dp$n_interior == 1))) }
