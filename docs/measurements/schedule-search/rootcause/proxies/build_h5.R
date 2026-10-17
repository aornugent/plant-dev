# build_h5.R: H5's ladders (rule N, s = 1.6 / 1 / 1/1.6) in lad.rds's shape, for every case
# whose three rungs have landed.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
HR <- file.path(OUT, "h5/runs"); base <- readRDS(file.path(PO, "lad.rds"))
one <- function(f, r) { if (!file.exists(f)) return(NULL); x <- readRDS(f); if (is.null(x$stand$elasticity)) return(NULL); q <- quantities(x)
  list(r = r, q = q[Q], S = sort(x$node_times), rows = x$stand$rows, cpu = x$stand$cpu + (if (is.null(x$sweep_cpu)) 0 else x$sweep_cpu), nrr = x$stand$nodes$nrr) }
L <- list()
for (cs in ALL) { runs <- list(x = one(file.path(HR, sprintf("h5_N16_%s.rds", cs)), 1.6), c = one(file.path(HR, sprintf("h5_N10_%s.rds", cs)), 1), f = one(file.path(HR, sprintf("h5_N06_%s.rds", cs)), 1 / 1.6))
  if (any(vapply(runs, is.null, TRUE))) next
  p <- pilot_ctx(cs); for (k in names(runs)) runs[[k]]$proxy <- alg$proxy_err(p, runs[[k]]$S)
  L[[cs]] <- list(case = cs, ref = REF$L19[[cs]][Q], runs = runs, pilot = p, E6c = base$L[[cs]]$runs$c) ; cat("H5 ladder:", cs, "\n") }
saveRDS(list(L = L, Q = Q, EPS = EPS, M_unit = M_unit), file.path(PO, "lad_h5.rds"))
