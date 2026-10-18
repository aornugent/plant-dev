# q7_maps.R: the ten committed runs' odd and even omit-one maps (dwr): per region, the
# field split into light and soil, the own part, and the region estimate D/3 from each
# parity. Drops whose merged interval spans a pilot edge are left out.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
u <- 0.025; out <- list()
hatw <- function(bc, bf, wf) { W <- numeric(length(bc)); j <- findInterval(bf, bc, rightmost.closed = TRUE); j[j < 1] <- 1; j[j >= length(bc)] <- length(bc) - 1
  t <- pmin(pmax((bf - bc[j]) / (bc[j + 1] - bc[j]), 0), 1); for (f in seq_along(bf)) { W[j[f]] <- W[j[f]] + wf[f] * (1 - t[f]); W[j[f] + 1] <- W[j[f] + 1] + wf[f] * t[f] }; W }
for (cs in BANK) { ea <- edges_all(cs); b1 <- pilot_of(cs)$b1
  for (par in c("a", "b")) { m <- readRDS(file.path(SC, "dwr/runs", sprintf("map_o1%s_%s.rds", par, cs))); S <- m$node_times; d <- m$dropped
    n <- m$stand$nodes; F <- n$nrr; w <- n$establishment[seq_along(S)]; J <- m$stand$J
    cross <- vapply(d, function(j) any(ea$b > S[j - 1] & ea$b < S[j + 1]), TRUE)
    reg <- ifelse(S[d] < b1, "F", ifelse(S[d] < 25, "I", "L")); reg[cross] <- "edge"
    for (g in c("F", "I", "L")) { k <- reg == g; if (!any(k)) next
      li <- sum(m$light[, k]) / J / u; so <- sum(m$soil[, k]) / J / u
      keep <- setdiff(seq_along(S), d[k]); own <- log(sum(hatw(S[keep], S, w) * F[keep]) / sum(w * F)) / u
      out[[length(out) + 1]] <- data.frame(case = cs, parity = par, region = g, drops = sum(k), light = li, soil = so, own = own, e = (own + li + so) / 3,
        soil_share = abs(so) / (abs(so) + abs(li))) } } }
tab <- do.call(rbind, out); options(width = 200); print(format(tab, digits = 3), row.names = FALSE)
w <- reshape(tab[, c("case", "parity", "region", "e")], idvar = c("case", "region"), timevar = "parity", direction = "wide")
w$diff <- w$e.a - w$e.b; w$rel <- abs(w$diff) / pmax(abs((w$e.a + w$e.b) / 2), 1e-9); print(format(w, digits = 3), row.names = FALSE)
saveRDS(list(tab = tab, parity = w), file.path(SC, "evidence", "q7_maps.rds"))
