# q3_own.R: the own part of the root_P50 elasticity's closing-zone error, dry against long-wet.
# Integrand G(b) s(b), G = density x nrr and s = d ln nrr / d ln root_P50 from the fate maps'
# forward differences (cl_map, cl_mapp). On each long-spell zone [p, c] (p the committed node
# before the inset), the hat on the committed inset layout {p, c - 12 d, a' + 12 d} against the
# integrand, by quadrature; in eps of root_P50's elasticity (summed over zones, / sum w G).
# Beside it the same for ln J (integrand G), and the measured region error (res) in root_P50.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
Sys.setenv(PLANT_LIB = file.path(dirname(ADJ), "libS")); suppressMessages(library(plant, lib.loc = Sys.getenv("PLANT_LIB")))
wb <- Weibull_Disturbance_Regime(40); dens <- function(t) vapply(t, wb$density, 0)
for (cs in c("dry", "long-wet")) { a <- rd(sprintf("cl_map_%s", cs)); p <- rd(sprintf("cl_mapp_%s", cs)); b <- a$stand$nodes$birth
  G <- dens(b) * a$stand$nodes$nrr; s <- (log(p$stand$nodes$nrr) - log(a$stand$nodes$nrr)) / log(1.02); W <- sum(a$stand$nodes$establishment[seq_along(b)] * G)
  cr <- PIL[[cs]]$cr; pr <- function(t) cr$rate[pmax(1, findInterval(t, cr$start))]
  Sc <- sort(rd(sprintf("val_insk_c_%s", cs))$node_times); et <- edge_table(cs); b1 <- PIL[[cs]]$b1; op <- et$b[et$opening]
  ce <- et[!et$opening & et$b > b1 & et$spell > 60, ]; tot <- c(lnJ = 0, P50 = 0, P50_edge3 = 0); n <- 0
  for (c0 in ce$b) { nx <- min(c(op[op > c0], 25)); hi <- nx + 12 / 365; j <- max(which(Sc < c0)); pp <- Sc[j - 1]
    if (pp < c0 - 120 / 365 || abs((c0 - Sc[j]) * 365 - 12) > 0.01) next
    k <- b >= pp - 3 / 365 & b <= hi + 1 / 365; if (max(b[k]) < hi - 1e-6) next
    f1 <- splinefun(b[k], G[k], method = "natural"); f2 <- splinefun(b[k], G[k] * s[k], method = "natural")
    own <- function(S, f) { t <- seq(pp, nx + 12 / 365, by = 0.05 / 365); gl <- approx(S, f(S), t, rule = 2)$y; sum(pr(t) * (f(t) - gl)) * 0.05 / 365 / W }
    S1 <- c(pp, c0 - 12 / 365, hi); S3 <- c(pp + (0:3) * (c0 - pp) / 3, hi)
    tot <- tot + c(own(S1, f1) / eps_vec("lnJ"), own(S1, f2) / eps_vec("root_P50"), own(S3, f2) / eps_vec("root_P50")); n <- n + 1 }
  reg <- -mv_run(rd(sprintf("cl_res_%s", cs)), rd(sprintf("val_insk_c_%s", cs)))
  cat(sprintf("%-9s %d zones | own part, committed inset: lnJ %+.4f eps, root_P50 %+.3f eps (edge, 3 intervals: %+.3f) | measured region root_P50 %+.3f, lnJ %+.3f\n",
    cs, n, tot["lnJ"], tot["P50"], tot["P50_edge3"], reg["root_P50"], reg["lnJ"])) }
