# e3_close.R: own part of the closing-zone error under layout D's local geometry: nodes at
# c - k h (k >= 1) over the 60 d before each long-spell closing edge c, none at c, the last
# node's chord to the next opening edge. Integrands G = density x nrr (ln J) and G s
# (root_P50's elasticity) from the fate maps; establishment from the pilot. In eps.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
Sys.setenv(PLANT_LIB = file.path(dirname(ADJ), "libS")); suppressMessages(library(plant, lib.loc = Sys.getenv("PLANT_LIB")))
wb <- Weibull_Disturbance_Regime(40); dens <- function(t) vapply(t, wb$density, 0)
HS <- c(2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 24, 30, 40, 48, 60); out <- list()
for (cs in c("dry", "long-wet")) { a <- rd(sprintf("cl_map_%s", cs)); p <- rd(sprintf("cl_mapp_%s", cs)); b <- a$stand$nodes$birth
  G <- dens(b) * a$stand$nodes$nrr; s <- (log(p$stand$nodes$nrr) - log(a$stand$nodes$nrr)) / log(1.02); W <- sum(a$stand$nodes$establishment[seq_along(b)] * G)
  cr <- PIL[[cs]]$cr; pr <- function(t) cr$rate[pmax(1, findInterval(t, cr$start))]
  et <- edge_table(cs); b1 <- PIL[[cs]]$b1; op <- et$b[et$opening]; ce <- et[!et$opening & et$b > b1 & et$spell > 60, ]
  E <- matrix(0, 2, length(HS)); Ec <- E; Dd <- c(0, 0); dl <- c(); n <- 0
  LD <- readRDS(sprintf("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence/layoutD_%s.rds", cs))$S
  for (c0 in ce$b) { nx <- min(op[op > c0]); pp <- c0 - 60 / 365
    k <- b >= pp - 4 / 365 & b <= nx + 1 / 365; if (min(b[k]) > pp + 1e-6 || max(b[k]) < nx - 6 / 365 || sum(k) < 25) next
    t <- seq(pp, nx, by = 0.05 / 365); prt <- pr(t)
    for (q in 1:2) { f <- splinefun(b[k], if (q == 1) G[k] else G[k] * s[k], method = "natural"); ft <- f(t)
      for (i in seq_along(HS)) { S <- sort(unique(c(pp, c0 - (1:floor(60 / HS[i])) * HS[i] / 365, nx))); S <- S[S >= pp - 1e-12]
        E[q, i] <- E[q, i] + sum(prt * (approx(S, f(S), t)$y - ft)) * 0.05 / 365 / W / eps_vec(if (q == 1) "lnJ" else "root_P50")
        S2 <- sort(unique(c(S, c0))); Ec[q, i] <- Ec[q, i] + sum(prt * (approx(S2, f(S2), t)$y - ft)) * 0.05 / 365 / W / eps_vec(if (q == 1) "lnJ" else "root_P50") }
      SD <- sort(unique(c(pp, LD[LD > pp & LD < nx], nx))); Dd[q] <- Dd[q] + sum(prt * (approx(SD, f(SD), t)$y - ft)) * 0.05 / 365 / W / eps_vec(if (q == 1) "lnJ" else "root_P50") }
    dl <- c(dl, (c0 - max(LD[LD < c0])) * 365)
    n <- n + 1 }
  cat(sprintf("%s: layout D's last node before c: median %.0f d [%.0f, %.0f]; its own part over these zones: lnJ %+.4f, root_P50 %+.4f eps\n", cs, median(dl), min(dl), max(dl), Dd[1], Dd[2]))
  out[[cs]] <- data.frame(case = cs, zones = n, h = HS, lnJ = E[1, ], root_P50 = E[2, ], cnode_lnJ = Ec[1, ], cnode_P50 = Ec[2, ],
    ratio_lnJ = c(E[1, -1] / E[1, -length(HS)], NA), ratio_P50 = c(E[2, -1] / E[2, -length(HS)], NA), h_next = c(HS[-1], NA), order_P50 = c(log(E[2, -1] / E[2, -length(HS)]) / log(HS[-1] / HS[-length(HS)]), NA),
    order_cnode_P50 = c(log(Ec[2, -1] / Ec[2, -length(HS)]) / log(HS[-1] / HS[-length(HS)]), NA)) }
tab <- do.call(rbind, out); options(width = 200); print(format(tab, digits = 3), row.names = FALSE)
cat("closing edges after b1 per case (all / spell > 60 d):\n"); for (cs in c("dry", "long-wet", "dry-flat", "episodic", "long-drought")) { et <- edge_table(cs); b1 <- PIL[[cs]]$b1
  cat(sprintf("  %s %d / %d\n", cs, sum(!et$opening & et$b > b1), sum(!et$opening & et$b > b1 & et$spell > 60))) }
saveRDS(tab, "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence/e3_close.rds")
