# grade.R: the shutting zones under B's density and under a density graded toward c.
# Integrands G (ln J) and G s (root_P50's elasticity) from the closing fate maps; establishment
# from the pilot. Per covered long-spell zone, over [c - 117 d, c]: the hat error of B's own
# nodes in that spell and of its odd removal, and the same for the graded spell. The grade
# g(d) = (kappa(d) / kappa_far)^(1/3) comes from the maps' median curvature profile of G s.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
Sys.setenv(PLANT_LIB = file.path(dirname(ADJ), "libS")); suppressMessages(library(plant, lib.loc = Sys.getenv("PLANT_LIB")))
wb <- Weibull_Disturbance_Regime(40); dens <- function(t) vapply(t, wb$density, 0)
EV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence"
W <- 117 / 365; DT <- 0.1 / 365; out <- list(); prof <- list()
load_case <- function(cs) { a <- rd(sprintf("cl_map_%s", cs)); p <- rd(sprintf("cl_mapp_%s", cs)); b <- a$stand$nodes$birth
  G <- dens(b) * a$stand$nodes$nrr; s <- (log(p$stand$nodes$nrr) - log(a$stand$nodes$nrr)) / log(1.02)
  list(b = b, G = G, s = s, Wt = sum(a$stand$nodes$establishment[seq_along(b)] * G)) }
for (cs in c("dry", "long-wet")) { M <- load_case(cs); B <- readRDS(file.path(EV, sprintf("layoutB_%s.rds", cs)))
  cr <- PIL[[cs]]$cr; pr <- function(t) cr$rate[pmax(1, findInterval(t, cr$start))]
  et <- edge_table(cs); b1 <- PIL[[cs]]$b1; ce <- et[!et$opening & et$b > b1 & et$spell > 60, ]
  zones <- list()
  for (c0 in ce$b) { k3 <- which(M$b >= c0 - W - 1e-9 & M$b <= c0 + 1e-9); if (length(k3) < 30) next
    if (max(diff(c(c0 - W, M$b[k3], c0))) > 3.5 / 365 || any(!is.finite(M$s[k3])) || any(!is.finite(M$G[k3]))) next
    j <- which.min(abs(B$breaks - c0)); if (abs(B$breaks[j] - c0) > 1e-6) next; o <- B$breaks[j - 1]
    ks <- which(M$b >= o - 1e-9 & M$b <= c0 + 1e-9); ks <- ks[is.finite(M$s[ks]) & is.finite(M$G[ks])]; zones[[length(zones) + 1]] <- list(c0 = c0, o = o, ks = ks, k3 = k3) }
  # curvature profile of G s by distance to c, each zone normalised by its 30-60 d median
  pr_d <- do.call(rbind, lapply(zones, function(z) { k <- z$k3; y <- M$G[k] * M$s[k]; d <- (z$c0 - M$b[k]) * 365
    k2 <- abs(diff(y, differences = 2)); dd <- d[2:(length(d) - 1)]; ref <- median(k2[dd >= 30 & dd <= 60]); data.frame(d = round(dd / 3) * 3, r = k2 / ref) }))
  kap <- tapply(pr_d$r, pr_d$d, median); dk <- as.numeric(names(kap)); kap <- stats::runmed(as.numeric(kap[order(dk)]), 3); dk <- sort(dk)
  kap[dk >= 30] <- 1; gfun <- approxfun(dk, pmax(1, kap)^(1 / 3), rule = 2)
  prof[[cs]] <- data.frame(case = cs, d = dk, kappa = kap, g = pmax(1, kap)^(1 / 3))
  pz <- list(); err <- matrix(0, 4, 2, dimnames = list(c("B", "B_removed", "graded", "graded_removed"), c("lnJ", "root_P50"))); nB <- 0; nG <- 0
  for (z in zones) { fi <- list(splinefun(M$b[z$ks], M$G[z$ks], method = "natural"), splinefun(M$b[z$ks], M$G[z$ks] * M$s[z$ks], method = "natural"))
    t <- seq(z$c0 - W, z$c0, by = DT); prt <- pr(t)
    inner <- B$S[B$S > z$o + 1e-9 & B$S < z$c0 - 1e-9]; n <- length(inner) + 1
    nodes_B <- c(z$o, inner, z$c0); rem_B <- c(z$o, inner[seq_along(inner) %% 2 == 0], z$c0)
    # graded: rho0 uniform at B's count over the spell, times g(d); even count at equal mass
    u <- seq(z$o, z$c0, length.out = 2001); um <- (head(u, -1) + u[-1]) / 2; rho <- n / (z$c0 - z$o) * gfun((z$c0 - um) * 365)
    cw <- c(0, cumsum(rho * diff(u))); ng <- 2 * ceiling(tail(cw, 1) / 2 - 1e-9)
    xg <- approx(cw / tail(cw, 1), u, seq(0, 1, length.out = ng + 1), ties = "ordered")$y; xg[1] <- z$o; xg[ng + 1] <- z$c0
    rem_g <- xg[c(1, seq(3, ng + 1, by = 2))]
    for (q in 1:2) { f <- fi[[q]]; ft <- f(t); ev <- if (q == 1) eps_vec("lnJ") else eps_vec("root_P50")
      e <- function(S) sum(prt * (approx(S, f(S), t)$y - ft)) * DT / M$Wt / ev
      v <- c(e(nodes_B), e(rem_B), e(xg), e(rem_g)); if (anyNA(v)) { cat("NA in zone", z$c0, cs, q, "\n"); next }
      err[, q] <- err[, q] + v; pz[[length(pz) + 1]] <- data.frame(c0 = z$c0, q = q, B = v[1], Brem = v[2], g = v[3], grem = v[4]) }
    nB <- nB + n; nG <- nG + ng }
  est <- (err[c(2, 4), ] - err[c(1, 3), ]) / 3; pz <- do.call(rbind, pz)
  zr <- function(q, a, b) { z <- pz[pz$q == q, ]; e <- z[[a]]; r <- (z[[b]] - e) / 3 / e; k <- abs(e) > 0.1 * max(abs(e)); median(r[k]) }
  out[[cs]] <- data.frame(case = cs, zones = length(zones), intervals_B = nB, intervals_graded = nG,
    B_lnJ = err[1, 1], B_P50 = err[1, 2], B_read_lnJ = est[1, 1] / err[1, 1], B_read_P50 = est[1, 2] / err[1, 2],
    g_lnJ = err[3, 1], g_P50 = err[3, 2], g_read_lnJ = est[2, 1] / err[3, 1], g_read_P50 = est[2, 2] / err[3, 2],
    B_abs_P50 = sum(abs(pz$B[pz$q == 2])), g_abs_P50 = sum(abs(pz$g[pz$q == 2])), B_zone_read_P50 = zr(2, "B", "Brem"), g_zone_read_P50 = zr(2, "g", "grem"),
    B_zone_read_lnJ = zr(1, "B", "Brem"), g_zone_read_lnJ = zr(1, "g", "grem")) }
P <- do.call(rbind, prof); print(format(P[P$d <= 42, ], digits = 3), row.names = FALSE)
tab <- do.call(rbind, out); options(width = 200); print(format(tab, digits = 3), row.names = FALSE)
saveRDS(list(profile = P, tab = tab), file.path(EV, "grade.rds"))
