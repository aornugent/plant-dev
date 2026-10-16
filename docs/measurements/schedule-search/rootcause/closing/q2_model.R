# q2_model.R CASE: the own part of the closing-edge error, computed from the fate map. G(b) =
# patch density x nrr, splined (on ln G) through the map's 3-d nodes over each long spell's last
# 120 d, its gap probes and the next spell's inset node; pr(b) the pilot's establishment rate.
# The hat over exact counts on a node set S misses int pr (G - G_lin,S) db; reported in eps of
# ln J (/ sum w G / 0.025), summed over the long-spell closing edges, split into the closing side
# [p, c] and the next opening strip [a', a' + 12 d] (read on the same gap chord).
# p is the committed schedule's node before the inset node (the start of a09's last interval);
# the zone [p, c] is the only part that changes. Representations, rung r (1.6, 1, 1/1.6):
#   inset(r): nodes p, uniform fill at spacing <= r h_end, c - 12 r; then a' + 12.
#   edge(n):  the edge a node and [p, c] cut into n equal intervals; then a' + 12.
#   d-scan:   inset at d with h_end fixed (P's in-d axis).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
Sys.setenv(PLANT_LIB = file.path(dirname(ADJ), "libS")); suppressMessages(library(plant, lib.loc = Sys.getenv("PLANT_LIB")))
cs <- commandArgs(TRUE)[1]; x <- readRDS(file.path(CL, "runs", sprintf("traj_map_%s.rds", cs)))
wb <- Weibull_Disturbance_Regime(40); dens <- function(t) vapply(t, wb$density, 0)
b <- x$birth; G <- dens(b) * x$nrr; W <- sum(x$w[seq_along(b)] * G)
cr <- PIL[[cs]]$cr; pr <- function(t) cr$rate[pmax(1, findInterval(t, cr$start))]
Sc <- sort(rd(sprintf("val_insk_c_%s", cs))$node_times)
et <- edge_table(cs); b1 <- PIL[[cs]]$b1; ce <- et[!et$opening & et$b > b1 & et$spell > 60, ]; op <- et$b[et$opening]
own <- function(S, lo, hi, f) { t <- seq(lo, hi, by = 0.05 / 365); gl <- approx(S, f(S), t, rule = 2)$y; sum(pr(t) * (f(t) - gl)) * 0.05 / 365 / W / 0.025 }
out <- list()
for (i in seq_len(nrow(ce))) { c0 <- ce$b[i]; nx <- min(c(op[op > c0], 25)); hi <- nx + 12 / 365
  j <- max(which(Sc < c0)); p <- Sc[j - 1]; if (p < c0 - 120 / 365 || abs((c0 - Sc[j]) * 365 - 12) > 0.01) next
  k <- b >= p - 3 / 365 & b <= hi + 1 / 365; sp <- splinefun(b[k], log(G[k]), method = "natural"); f <- function(t) exp(sp(t))
  if (max(b[k]) < hi - 1e-6) next
  Z <- (c0 - p) * 365; hend <- Z - 12
  E2 <- function(S) c(close = own(S, p, c0 + 2 / 365, f), open = own(S, nx, hi, f))
  ins <- function(r, d = 12 * r, m = max(1, ceiling((Z - d) / (r * hend) - 1e-9))) { S <- c(p + (0:(m - 1)) * (Z - d) / m / 365, c0 - d / 365, hi); E2(S) }
  # The derivation's closed form for the d-scan (one interval [p, c - d], then the gap chord to
  # a' + 12): -pr g2 h^3/12 + pr [(g1 - sigma) d^2/2 + g2 d^3/6], g1, g2 of G at c - d (days),
  # pr the spell's rate over [c - 36, c - 11]; the opening strip left to the numeric.
  taylor <- function(d) { x0 <- c0 - d / 365; L <- sp(x0, 1) / 365; L2 <- sp(x0, 2) / 365^2; g0 <- f(x0); g1 <- g0 * L; g2 <- g0 * (L2 + L^2)
    h <- Z - d; D <- (hi - x0) * 365; sig <- (f(hi) - g0) / D; p0 <- mean(pr(c0 - seq(11, 36, by = 0.25) / 365))
    c(close = p0 * (-g2 * h^3 / 12 + (g1 - sig) * d^2 / 2 + g2 * d^3 / 6) / 365 / W / 0.025, open = NA) }
  edg <- function(n) E2(c(p + (0:n) * Z / n / 365, hi))
  rows <- rbind(data.frame(rep = "inset", r = c(1.6, 1, 1 / 1.6), t(sapply(c(1.6, 1, 1 / 1.6), ins))),
    data.frame(rep = "edge", r = c(3 / 2, 3 / 3, 3 / 5), t(sapply(c(2, 3, 5), edg))),
    data.frame(rep = "edge1", r = 1, t(edg(1))),
    data.frame(rep = sprintf("d%g", c(0, 3, 7.5, 10, 12, 15, 19.2, 25, 36)), r = 1, t(sapply(c(0, 3, 7.5, 10, 12, 15, 19.2, 25, 36), function(d) ins(1, d, m = 1)))),
    data.frame(rep = sprintf("T%g", c(0, 3, 7.5, 10, 12, 15, 19.2, 25, 36)), r = 1, t(sapply(c(0, 3, 7.5, 10, 12, 15, 19.2, 25, 36), function(d) taylor(d))), row.names = NULL))
  out[[i]] <- cbind(edge = c0, Z = Z, gap = ce$gap[i], rows) }
R <- do.call(rbind, out); saveRDS(R, file.path(CL, sprintf("q2_model_%s.rds", cs)))
A <- aggregate(cbind(close, open) ~ rep + r, R, sum, na.action = na.pass); A$total <- A$close + A$open
dd <- c(0, 3, 7.5, 10, 12, 15, 19.2, 25, 36); num <- A$close[match(sprintf("d%g", dd), A$rep)]; tay <- A$close[match(sprintf("T%g", dd), A$rep)]
cat("d-scan (h_end = Z - d, count kept), close side: numeric quadrature vs the closed form; move from d = 0 relative to d = 10:\n")
print(data.frame(d = dd, numeric = num, closed_form = tay, p_num = (num - num[1]) / (num[4] - num[1]), p_cf = (tay - tay[1]) / (tay[4] - tay[1])), digits = 3, row.names = FALSE)
cat(sprintf("%s: %d long-spell edges used (Z median %.0f d); own part of ln J error in eps, summed\n", cs, length(unique(R$edge)), median(unique(R[, c("edge", "Z")])$Z)))
print(A[order(A$rep, -A$r), ], digits = 3, row.names = FALSE)
for (rp in c("inset", "edge")) { a <- A[A$rep == rp, ]; a <- a[order(-a$r), ]
  cat(sprintf("%s ladder (close side): x/c %.2f (square law %.2f), c/f %.2f (square law %.2f)\n", rp, a$close[1] / a$close[2], (a$r[1] / a$r[2])^2, a$close[2] / a$close[3], (a$r[2] / a$r[3])^2)) }
