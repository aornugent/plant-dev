# Uniform ladders with three rungs: per-quantity convergence ratio (u215 - u429) / (u429 - u857).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
H <- file.path(SP, "deep/rootcause/heldout/runs"); RR <- file.path(SP, "deep/rootcause/refine/runs")
get <- function(cs, n) { for (d in c(RR, H)) { f <- file.path(d, sprintf("ref_%s_u%d.rds", cs, n)); if (file.exists(f)) return(qv(readRDS(f)) / EPS) }; NULL }
qs <- c("a_l1", "lnJ", "a", "k_I", "jmax_25", "lma", "storage_relaxation_offset", "k_s", "hmat", "TF24_cost_scale")
for (cs in c("episodic-lma", "flat-al1125", "dry-lma125", "wet-hmat125")) { u <- lapply(c(215, 429, 857), function(n) get(cs, n)); if (any(vapply(u, is.null, TRUE))) { cat(cs, "missing rung\n"); next }
  d1 <- u[[1]] - u[[2]]; d2 <- u[[2]] - u[[3]]
  cat(cs, "\n"); print(round(rbind(d215_429 = d1[qs], d429_857 = d2[qs], ratio = (d1 / d2)[qs]), 3)) }
