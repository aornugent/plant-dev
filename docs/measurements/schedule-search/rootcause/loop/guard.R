# guard.R: the scratch build (MODE=map, unpinned) on E6's committed dry schedule against the
# saved libS run val_insk_c_dry: J, step count and the 50 trait gradients identical(); the
# map's ln J error against the dwr round's figure; the map's sweep cost against the plain one.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/lib.R")
x <- readRDS(file.path(LO, "runs", "g_e6c_dry.rds")); b <- readRDS(file.path(AR, "val_insk_c_dry.rds"))
g0 <- unname(b$stand$gradient); g1 <- unname(x$stand$gradient)
cat(sprintf("J identical %s (%.15g vs %.15g); steps %d vs %d, times identical %s; 50 gradients identical %s (max rel %.1e); elasticities identical %s\n",
  identical(x$stand$J, b$stand$J), x$stand$J, b$stand$J, length(x$stand$times), length(b$stand$times), identical(x$stand$times, b$stand$times),
  identical(g0, g1), max(abs(g1 / g0 - 1)), identical(unname(x$stand$elasticity), unname(b$stand$elasticity))))
d <- drop_set("dry", x$node_times); stopifnot(identical(as.integer(x$dropped), as.integer(d$drop)))
m <- map_lnJ(x, d$region); print(round(m, 4))
cat(sprintf("map all %.4f against dwr -0.1234 | sweep: plain %.0f s, map %.0f s (x%.3f); forward %.0f s\n", m[["all"]], x$sweep0_cpu, x$sweep_cpu, x$sweep_cpu / x$sweep0_cpu, x$stand$cpu))
