# twin_analyze.R: the storage offset's per-cohort sensitivity s_sro on the closing fate map
# (twin against cl_map_dry), beside root_P50's. Where its curvature rises; where it has slope
# jumps at 3 d; where neighbouring cohorts' lowest reserve crosses 0.15; and the shutting
# zones' interpolation error for G s_sro under B, its removal, and the graded density.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
Sys.setenv(PLANT_LIB = file.path(dirname(ADJ), "libS")); suppressMessages(library(plant, lib.loc = Sys.getenv("PLANT_LIB")))
wb <- Weibull_Disturbance_Regime(40); dens <- function(t) vapply(t, wb$density, 0)
EV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence"
a <- rd("cl_map_dry"); pp <- rd("cl_mapp_dry"); tw <- readRDS(file.path(EV, "runs", "twin_sro_dry.rds")); b <- a$stand$nodes$birth
stopifnot(max(abs(b - tw$birth)) < 1e-12)
cat(sprintf("J base %.10g, twin %.10g (d ln J / d ln sro %.4f; reference elasticity at c %.4f)\n", a$stand$J, tw$J, log(tw$J / a$stand$J) / log(1.02), NA))
s1 <- (log(tw$nrr) - log(a$stand$nodes$nrr)) / log(1.02); s2 <- (log(pp$stand$nodes$nrr) - log(a$stand$nodes$nrr)) / log(1.02)
G <- dens(b) * a$stand$nodes$nrr; Wt <- sum(a$stand$nodes$establishment[seq_along(b)] * G)
cr <- PIL[["dry"]]$cr; pr <- function(t) cr$rate[pmax(1, findInterval(t, cr$start))]
et <- edge_table("dry"); b1 <- PIL[["dry"]]$b1; ce <- et[!et$opening & et$b > b1 & et$spell > 60, ]; W <- 117 / 365
B <- readRDS(file.path(EV, "layoutB_dry.rds")); prof <- list(); kinks <- list(); cross <- list(); zones <- list()
for (c0 in ce$b) { k3 <- which(b >= c0 - W - 1e-9 & b <= c0 + 1e-9); if (length(k3) < 30) next
  if (max(diff(c(c0 - W, b[k3], c0))) > 3.5 / 365 || any(!is.finite(s1[k3]))) next
  d <- (c0 - b[k3]) * 365; zones[[length(zones) + 1]] <- c0
  for (nm in c("sro", "root_P50")) { y <- (if (nm == "sro") s1 else s2)[k3]; yg <- G[k3] * y
    d2 <- diff(yg, differences = 2); dd <- d[2:(length(d) - 1)]; ref <- median(abs(d2[dd >= 30 & dd <= 60]))
    prof[[length(prof) + 1]] <- data.frame(q = nm, c0 = c0, d = round(dd / 3) * 3, r = abs(d2) / ref)
    # slope jumps on s itself: 3-d and 6-d second differences on the 3-d grid
    m <- length(y); j <- 3:(m - 2); a1 <- y[j - 1] - 2 * y[j] + y[j + 1]; a2 <- y[j - 2] - 2 * y[j] + y[j + 2]; kap <- abs(a1 - a2 / 4)
    big <- kap > 5 * median(kap) & abs(a2) / pmax(abs(a1), 1e-12) <= 2.8
    if (any(big)) kinks[[length(kinks) + 1]] <- data.frame(q = nm, c0 = c0, d = d[j][big], kap_rel = kap[big] / median(kap)) }
  rm <- tw$rmin[k3]; x <- which(diff(rm < 0.15) != 0)
  cross[[length(cross) + 1]] <- data.frame(c0 = c0, d_cross = if (length(x)) paste(round((d[x] + d[x + 1]) / 2), collapse = ",") else "none",
    rmin_at_c36 = rm[which.min(abs(d - 36))], rmin_at_c12 = rm[which.min(abs(d - 12))], rmin_at_c = rm[which.min(abs(d - 0))]) }
P <- do.call(rbind, prof); pt <- aggregate(r ~ q + d, P, median); pt <- pt[pt$d <= 45, ]
cat("curvature of G s by days before c, median over zones, relative to 30-60 d:\n"); print(reshape(pt, idvar = "d", timevar = "q", direction = "wide"), row.names = FALSE, digits = 3)
K <- if (length(kinks)) do.call(rbind, kinks) else NULL
cat(sprintf("zones %d; slope-jump candidates (kappa > 5x zone median and ratio <= 2.8) by quantity:\n", length(zones)))
if (!is.null(K)) { print(table(K$q, cut(K$d, c(-1, 6, 15, 30, 60, 120)))) }
cat("lowest reserve r_min crossing 0.15 between neighbours, days before c:\n"); print(do.call(rbind, cross), row.names = FALSE, digits = 3)
# interpolation error of G s_sro in the shutting zones: B, its removal, graded (count held and +even ceiling)
gp <- readRDS(file.path(EV, "grade.rds"))$profile; gp <- gp[gp$case == "dry", ]; gfun <- approxfun(gp$d, gp$g, rule = 2)
DT <- 0.1 / 365; E <- matrix(0, 6, 2, dimnames = list(c("B", "Brem", "gfix", "gfix_rem", "gadd", "gadd_rem"), c("sro", "root_P50")))
for (c0 in unlist(zones)) { j <- which.min(abs(B$breaks - c0)); if (abs(B$breaks[j] - c0) > 1e-6) next; o <- B$breaks[j - 1]
  ks <- which(b >= o - 1e-9 & b <= c0 + 1e-9); ks <- ks[is.finite(s1[ks])]; t <- seq(c0 - W, c0, by = DT); prt <- pr(t)
  inner <- B$S[B$S > o + 1e-9 & B$S < c0 - 1e-9]; n <- length(inner) + 1; nB <- c(o, inner, c0); rB <- c(o, inner[seq_along(inner) %% 2 == 0], c0)
  u <- seq(o, c0, length.out = 2001); um <- (head(u, -1) + u[-1]) / 2; rho <- n / (c0 - o) * gfun((c0 - um) * 365); cw <- c(0, cumsum(rho * diff(u)))
  place <- function(ng) { x <- approx(cw / tail(cw, 1), u, seq(0, 1, length.out = ng + 1), ties = "ordered")$y; x[1] <- o; x[ng + 1] <- c0; x }
  xf <- place(max(n, 2)); xa <- place(2 * ceiling(tail(cw, 1) / 2 - 1e-9)); rem <- function(x) x[c(1, seq(3, length(x), by = 2))]
  for (q in 1:2) { f <- splinefun(b[ks], G[ks] * (if (q == 1) s1 else s2)[ks], method = "natural"); ft <- f(t); ev <- eps_vec(if (q == 1) "storage_relaxation_offset" else "root_P50")
    e <- function(S) sum(prt * (approx(S, f(S), t)$y - ft)) * DT / Wt / ev
    E[, q] <- E[, q] + c(e(nB), e(rB), e(xf), e(rem(xf)), e(xa), e(rem(xa))) } }
rd3 <- function(i) (E[i + 1, ] - E[i, ]) / 3 / E[i, ]
cat("shutting zones' interpolation error (eps) and the removal's read:\n"); print(round(rbind(E, read_B = rd3(1), read_gfix = rd3(3), read_gadd = rd3(5)), 4))
saveRDS(list(prof = P, kinks = K, cross = cross, E = E), file.path(EV, "twin_analyze.rds"))
