# gap.R [CASE...]: where U (s = 1) falls behind E6 committed, by region. Per layout (E6
# committed, U10, E6+ at s = 1) and region (founders F; interiors b1-10, 10-17, 17-25; opening
# strips o and o + 12 d; closing strips c - 12 d and c; short-spell centres; late >= 25):
# nodes, rows (each node's share: the accepted steps it is alive for), the a09 proxy (each
# interval's w h^3 by its midpoint's region), and the node-drop map's ln J error by region
# where a map run exists (the strips' part is the measured ln J error less the map's total).
# Then spell by spell before 25, the background (non-strip) nodes of E6 and U.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/loop_run.R")
args <- commandArgs(TRUE); todo <- if (length(args)) args else c("dry", "dry-flat", "long-wet")
UR <- file.path(SP, "deep/rootcause/u/runs"); rms <- function(x) sqrt(mean(x^2))
pa <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a04_proxy.R", pa)
int_class <- function(cs, m) { p <- pilot_of(cs); et <- edge_table(cs); cl <- et$b[!et$opening]; op <- et$b[et$opening]; d <- 12 / 365
  vapply(m, function(b) { if (b >= 25) return("late"); if (any(cl - b > 0 & cl - b <= d)) return("cstrip"); if (any(b - op > 0 & b - op <= d)) return("ostrip")
    if (b < p$b1) return("F"); if (b < 10) "I1" else if (b < 17) "I2" else "I3" }, "") }
REG <- c("F", "I1", "I2", "I3", "ostrip", "cstrip", "short", "late")
for (cs in todo) { p <- pilot_of(cs); ref <- ref_of(cs)
  L <- list(E6 = readRDS(file.path(AR, sprintf("val_insk_c_%s.rds", cs))), U10 = readRDS(file.path(UR, sprintf("h5_U10_%s.rds", cs))), `E6+` = ep_read(cs, 1))
  MP <- list(E6 = if (cs == "dry") readRDS(file.path(LO, "runs", "g_e6c_dry.rds")) else { f <- file.path(LO, "runs", sprintf("gE6c_%s.rds", cs)); if (file.exists(f)) readRDS(f) },
            U10 = { f <- file.path(LO, "runs", sprintf("gU10_%s.rds", cs)); if (file.exists(f)) readRDS(f) }, `E6+` = L$`E6+`)
  cat(sprintf("\n==== %s (b1 %.2f)\n", cs, p$b1))
  for (k in names(L)) { x <- L[[k]]; if (is.null(x)) next; S <- sort(x$node_times); t0 <- head(x$stand$times, -1)
    alive <- vapply(S, function(b) sum(t0 >= b - 1e-12), 0); nc <- factor(node_class(cs, S), REG)
    lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2; w <- exp(pa$PW * approxfun(p$nodes$birth, log(pmax(p$nodes$nrr, 1e-300)), rule = 2)(m)); w[p$shut(m) > 0.5] <- 0
    pr <- tapply(w * (hi - lo)^3, factor(int_class(cs, m), REG), sum); pr[is.na(pr)] <- 0
    e <- (qv(x) - ref) / EPS; mp <- if (!is.null(MP[[k]]) && !is.null(MP[[k]]$light)) map_by_era(cs, MP[[k]]) else NULL
    me <- setNames(rep(NA, length(REG)), REG); if (!is.null(mp)) { for (g in intersect(names(mp), REG)) me[g] <- mp[[g]]; me["cstrip"] <- e[["lnJ"]] - mp[["all"]] }
    tab <- data.frame(region = REG, nodes = as.vector(table(nc)), rows = as.vector(tapply(alive, nc, sum)), proxy_share = as.vector(pr / sum(pr)), map_lnJ = as.vector(me))
    tab$rows[is.na(tab$rows)] <- 0
    cat(sprintf("-- %s: %d nodes, %.0f rows (x%.2f E6), worst %.2f (%s), rms %.3f, along M %+.2f, lnJ err %+.3f, map total %s | proxy %.4g\n", k, length(S), x$stand$rows, x$stand$rows / L$E6$stand$rows,
      max(abs(e)), Q[which.max(abs(e))], rms(e), sum(e * M), e[["lnJ"]], if (is.null(mp)) "n/a" else sprintf("%+.3f", mp[["all"]]), sum(pr)))
    print(format(tab, digits = 3), row.names = FALSE) }
  # Spell by spell before 25: background nodes (non-strip, non-edge) of E6 and U10.
  et <- edge_table(cs); op <- et$b[et$opening]; sp <- list()
  for (o in op[op < 25]) { c1 <- min(et$b[!et$opening & et$b > o], 25); bg <- function(S) { z <- S[S > o + 12 / 365 + 1e-6 & S < c1 - 12 / 365 - 1e-6]; length(z) }
    sp[[length(sp) + 1]] <- c(o = o, len = (c1 - o) * 365, E6 = bg(L$E6$node_times), U10 = bg(L$U10$node_times), E6p = if (is.null(L$`E6+`)) NA else bg(L$`E6+`$node_times)) }
  sp <- as.data.frame(do.call(rbind, sp))
  cat(sprintf("spells before 25: %d; background nodes E6 %d, U10 %d; spells where U10 has fewer %d (by %d nodes), more %d; by length: <60 d E6 %d U %d | 60-150 d E6 %d U %d | >150 d E6 %d U %d; before 10: E6 %d U %d\n",
    nrow(sp), sum(sp$E6), sum(sp$U10), sum(sp$U10 < sp$E6), sum(pmax(sp$E6 - sp$U10, 0)), sum(sp$U10 > sp$E6),
    sum(sp$E6[sp$len < 60]), sum(sp$U10[sp$len < 60]), sum(sp$E6[sp$len >= 60 & sp$len < 150]), sum(sp$U10[sp$len >= 60 & sp$len < 150]), sum(sp$E6[sp$len >= 150]), sum(sp$U10[sp$len >= 150]),
    sum(sp$E6[sp$o < 10]), sum(sp$U10[sp$o < 10]))) }
