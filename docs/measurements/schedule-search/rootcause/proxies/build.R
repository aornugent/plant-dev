# build.R: one small file with everything the proxy and loop scripts read, per case: the
# E6-family ladder (x 1.6, c 1, f 1/1.6, insk_f, insx12), the founders' bisection, the
# pilot, the reference, quantities, rows, CPU and node times.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
H1R <- file.path(OUT, "h1/runs"); FOR <- file.path(OUT, "founders/runs")
rd1 <- function(f) if (file.exists(f)) readRDS(f)
one <- function(x, r, tag) { if (is.null(x) || is.null(x$stand$elasticity)) return(NULL)
  q <- quantities(x); list(tag = tag, r = r, q = q[Q], S = sort(x$node_times), rows = x$stand$rows, steps = length(x$stand$times),
    cpu = x$stand$cpu + (if (is.null(x$sweep_cpu)) 0 else x$sweep_cpu), cpu_fwd = x$stand$cpu, nrr = x$stand$nodes$nrr) }
lat <- readRDS(file.path(OUT, "founders/q1_lattice.rds")); fc <- readRDS(file.path(OUT, "founders/q1_committed.rds"))
L <- list()
for (cs in ALL) {
  runs <- list(x = one(rd1(file.path(H1R, sprintf("val_insx_x_%s.rds", cs))), 1.6, "x"),
    c = one(rd1(file.path(AR, sprintf("val_insk_c_%s.rds", cs))), 1, "c"),
    f = one(rd1(file.path(AR, sprintf("val_ins75_f_%s.rds", cs))), 1 / 1.6, "f"),
    f12 = one(rd1(file.path(AR, sprintf("val_insk_f_%s.rds", cs))), 1 / 1.6, "f12"),
    x12 = one(rd1(file.path(H1R, sprintf("val_insx12_x_%s.rds", cs))), 1.6, "x12"),
    fbis = one(rd1(file.path(FOR, sprintf("fbis_%s.rds", cs))), NA, "fbis"))
  runs <- runs[!vapply(runs, is.null, TRUE)]
  p <- pilot_ctx(cs)
  for (k in names(runs)) runs[[k]]$proxy <- alg$proxy_err(p, runs[[k]]$S)
  L[[cs]] <- list(case = cs, ref = REF$L19[[cs]][Q], runs = runs, pilot = p, eF32 = lat[[cs]]$eF32[Q], F = fc[[cs]]$F[Q], e_fc = fc[[cs]]$e[Q])
  cat(cs, paste(names(runs), collapse = " "), "\n") }
saveRDS(list(L = L, Q = Q, EPS = EPS, M_unit = M_unit), file.path(PO, "lad.rds"))
