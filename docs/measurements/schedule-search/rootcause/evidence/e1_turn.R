# e1_turn.R: the root_P50 sensitivity s(b) = (ln nrr at x1.02 - ln nrr) / ln 1.02 on the 3-d
# fate maps, near closing edges (cl_map/cl_mapp, dry and long-wet) and opening edges
# (h5 omap, dry). At h = 3, 6, 12, 24 d: |D2(2h)|/|D2h| and kappa = |D2h - D2(2h)/4|
# centred at each offset from the edge, median over edges.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
sv <- function(a, p) list(b = a$stand$nodes$birth, s = (log(p$stand$nodes$nrr) - log(a$stand$nodes$nrr)) / log(1.02), y = log(a$stand$nodes$nrr))
at <- function(M, x) { j <- which(abs(M$b - x) < 0.6 / 365); if (length(j)) j[1] else NA }
stencil <- function(M, x, h, v) { j <- sapply(c(-2, -1, 0, 1, 2) * h / 365 + x, function(z) at(M, z)); if (anyNA(j)) return(c(NA, NA))
  y <- M[[v]][j]; c(y[2] - 2 * y[3] + y[4], y[1] - 2 * y[3] + y[5]) }
out <- list()
for (cs in c("dry", "long-wet")) { M <- sv(readRDS(file.path(SC, "closing/runs", sprintf("cl_map_%s.rds", cs))), readRDS(file.path(SC, "closing/runs", sprintf("cl_mapp_%s.rds", cs))))
  ea <- edges_all(cs); cl <- ea$b[!ea$opening]
  for (v in c("s", "y")) for (h in c(3, 6, 12, 24)) for (off in c(-60, -48, -36, -24, -18, -12, -9, -6, -3)) {
    z <- t(sapply(cl, function(c0) stencil(M, c0 + off / 365, h, v))); z <- z[complete.cases(z), , drop = FALSE]; if (nrow(z) < 3) next
    out[[length(out) + 1]] <- data.frame(case = cs, side = "closing", v = v, h = h, off = off, n = nrow(z), ratio = median(abs(z[, 2])) / median(abs(z[, 1])),
      kap = median(abs(z[, 1] - z[, 2] / 4)), d1 = median(abs(z[, 1]))) } }
M <- sv(readRDS(file.path(SC, "h5/runs/h5_omap_dry.rds")), readRDS(file.path(SC, "h5/runs/h5_omap@p_dry.rds"))); ea <- edges_all("dry"); op <- ea$b[ea$opening]
for (v in c("s", "y")) for (h in c(3, 6, 12)) for (off in c(-3, 0, 3, 6, 9, 12, 18, 24, 30, 36)) {
  z <- t(sapply(op, function(o) stencil(M, o + off / 365, h, v))); z <- z[complete.cases(z), , drop = FALSE]; if (nrow(z) < 3) next
  out[[length(out) + 1]] <- data.frame(case = "dry", side = "opening", v = v, h = h, off = off, n = nrow(z), ratio = median(abs(z[, 2])) / median(abs(z[, 1])),
    kap = median(abs(z[, 1] - z[, 2] / 4)), d1 = median(abs(z[, 1]))) }
tab <- do.call(rbind, out); options(width = 200); print(format(tab, digits = 3), row.names = FALSE)
saveRDS(tab, file.path(SC, "evidence", "e1_turn.rds"))
