# q4_own.R: the ladders' own part on the root_P50 sensitivity integrand G s (as q3_own.R), dry,
# zones covered by the fate map. Representations on [p, c] (then a' + 12 d):
#   edgN: the edge a node, [p, c] in N equal intervals (N = 2, 3, 5);
#   ins : the inset rule's strip-only rungs (19.2 d; 12 d; 7.5 d with [p, c - 7.5] split);
#   tN  : the edge a node, a fixed node at c - 12 d, [p, c - 12] in N intervals (N = 1, 2, 3).
# Also a one-kink model: an interval of width h ending at the edge over an integrand with a
# slope turn delta days before the edge errs in proportion to delta (h - delta).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
Sys.setenv(PLANT_LIB = file.path(dirname(ADJ), "libS")); suppressMessages(library(plant, lib.loc = Sys.getenv("PLANT_LIB")))
wb <- Weibull_Disturbance_Regime(40); dens <- function(t) vapply(t, wb$density, 0)
cs <- commandArgs(TRUE)[1]; a <- rd(sprintf("cl_map_%s", cs)); p <- rd(sprintf("cl_mapp_%s", cs)); b <- a$stand$nodes$birth
G <- dens(b) * a$stand$nodes$nrr; s <- (log(p$stand$nodes$nrr) - log(a$stand$nodes$nrr)) / log(1.02); W <- sum(a$stand$nodes$establishment[seq_along(b)] * G)
cr <- PIL[[cs]]$cr; pr <- function(t) cr$rate[pmax(1, findInterval(t, cr$start))]
Sc <- sort(rd(sprintf("val_insk_c_%s", cs))$node_times); et <- edge_table(cs); b1 <- PIL[[cs]]$b1; op <- et$b[et$opening]
ce <- et[!et$opening & et$b > b1 & et$spell > 60, ]
reps <- list(edg2 = function(pp, c0) pp + (0:2) * (c0 - pp) / 2, edg3 = function(pp, c0) pp + (0:3) * (c0 - pp) / 3, edg5 = function(pp, c0) pp + (0:5) * (c0 - pp) / 5,
  insx = function(pp, c0) c(pp, c0 - 19.2 / 365), insc = function(pp, c0) c(pp, c0 - 12 / 365),
  insf = function(pp, c0) { L <- (c0 - pp) * 365; m <- ceiling((L - 7.5) / ((L - 12) / 1.6) - 1e-9); c(pp + (0:(m - 1)) * (L - 7.5) / m / 365, c0 - 7.5 / 365) },
  t1 = function(pp, c0) c(pp, c0 - 12 / 365, c0), t2 = function(pp, c0) c(pp + (0:1) * (c0 - 12 / 365 - pp) / 2, c0 - 12 / 365, c0), t3 = function(pp, c0) c(pp + (0:2) * (c0 - 12 / 365 - pp) / 3, c0 - 12 / 365, c0),
  res = function(pp, c0) pp + (0:15) * (c0 - pp) / 15)
tot <- setNames(numeric(length(reps)), names(reps)); n <- 0
for (c0 in ce$b) { nx <- min(c(op[op > c0], 25)); hi <- nx + 12 / 365; j <- max(which(Sc < c0)); pp <- Sc[j - 1]
  if (pp < c0 - 120 / 365 || abs((c0 - Sc[j]) * 365 - 12) > 0.01) next
  k <- b >= pp - 3 / 365 & b <= hi + 1 / 365; if (max(b[k]) < hi - 1e-6) next
  f <- splinefun(b[k], G[k] * s[k], method = "natural"); t <- seq(pp, hi, by = 0.05 / 365); ft <- f(t); prt <- pr(t)
  own <- function(S) { S <- c(S, hi); gl <- approx(S, f(S), t, rule = 2)$y; sum(prt * (ft - gl)) * 0.05 / 365 / W / eps_vec("root_P50") }
  tot <- tot + vapply(reps, function(r) own(r(pp, c0)), 0); n <- n + 1 }
z <- tot - tot["res"]
cat(sprintf("%s, %d zones: own part of the root_P50 zone error (eps), against the 15-interval reference\n", cs, n)); print(round(z, 4))
cat(sprintf("edg ladder x/c %.2f (law 2.25) c/f %.2f (law 2.78) | inset x/c %.2f (law 2.56) c/f %.2f (law 2.56) | t ladder t1/t2 %.2f (law 4) t2/t3 %.2f (law 2.25)\n",
  z["edg2"] / z["edg3"], z["edg3"] / z["edg5"], z["insx"] / z["insc"], z["insc"] / z["insf"], z["t1"] / z["t2"], z["t2"] / z["t3"]))
d <- 10; h <- 74 / c(2, 3, 5); cat(sprintf("one-kink model, delta %g d, h = Z/N at Z 74 d: errors in proportion %.2f : %.2f : %.2f -> x/c %.2f, c/f %.2f\n", d, d * (h[1] - d), d * (h[2] - d), d * (h[3] - d), (h[1] - d) / (h[2] - d), (h[2] - d) / (h[3] - d)))
