# build_lad.R [RULE]: a ladder (RULE16 / RULE10 / RULE06, default U; s = 1.6 / 1 / 1/1.6) in the
# proxies round's lad.rds shape, for every case whose three rungs have landed, for b_loop.R.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
PO <- file.path(OUT, "proxies"); UR <- file.path(OUT, "u/runs"); RULE <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "U"
base <- readRDS(file.path(PO, "lad.rds"))
one <- function(f, r) { if (!file.exists(f)) return(NULL); x <- readRDS(f); if (is.null(x$stand$elasticity)) return(NULL); q <- quantities(x)
  list(r = r, q = q[Q], S = sort(x$node_times), rows = x$stand$rows, cpu = x$stand$cpu + (if (is.null(x$sweep_cpu)) 0 else x$sweep_cpu), nrr = x$stand$nodes$nrr) }
L <- list()
for (cs in ALL) { runs <- list(x = one(file.path(UR, sprintf("h5_%s16_%s.rds", RULE, cs)), 1.6), c = one(file.path(UR, sprintf("h5_%s10_%s.rds", RULE, cs)), 1), f = one(file.path(UR, sprintf("h5_%s06_%s.rds", RULE, cs)), 1 / 1.6))
  if (any(vapply(runs, is.null, TRUE))) next
  p <- pilot_ctx(cs); for (k in names(runs)) runs[[k]]$proxy <- alg$proxy_err(p, runs[[k]]$S)
  L[[cs]] <- list(case = cs, ref = REF$L19[[cs]][Q], runs = runs, pilot = p, E6c = base$L[[cs]]$runs$c) }
cat(RULE, "ladders:", paste(names(L), collapse = " "), "\n")
saveRDS(list(L = L, Q = Q, EPS = EPS, M_unit = M_unit), file.path(OUT, "u", sprintf("lad_%s.rds", RULE)))
