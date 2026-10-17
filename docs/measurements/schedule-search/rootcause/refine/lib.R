# lib.R: the refine round's cases, run backend (request and replay), uniform ladder and
# references. Sources the loop round's library (cases, E6 runs, map, drop sets).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/lib.R")
source("/home/user/plant-dev/harness/schedule/refine.R")
RO <- file.path(SP, "deep/rootcause/refine")
RUNSH <- "/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/run.sh"
tag_of_tol <- function(tol) sprintf("%.0e", tol)
hash_S <- function(S) sum(round(S * 1e6) %% 9973 * seq_along(S)) %% 1e6
rf_name <- function(cs, tol, S) sprintf("rf_%s_%s_%d_%06d", cs, tag_of_tol(tol), length(S), hash_S(S))
un_name <- function(cs, tol, k) sprintf("un_%s_%s_k%d", cs, tag_of_tol(tol), k)

# E6's committed and check schedules as built and run (libS, 1e-4).
e6_runs <- function(cs) {
  if (cs %in% BANK) { r <- LAD$L[[cs]]$runs
    return(list(S0 = r$c$S, S1 = r$f$S, x0 = readRDS(file.path(AR, sprintf("val_insk_c_%s.rds", cs))),
                x1 = readRDS(file.path(AR, sprintf("val_ins75_f_%s.rds", cs))))) }
  x0 <- HO_RUN(paste0("e6_c_", cs)); x1 <- HO_RUN(paste0("e6_f_", cs))
  list(S0 = sort(x0$node_times), S1 = sort(x1$node_times), x0 = x0, x1 = x1) }

# Runs requested, not launched: a missing run is prepared, its job written to REQ, and the
# case stops with class "need_run"; run.sh runs the jobs and the driver starts again.
REQ <- Sys.getenv("REQ", file.path(RO, "requests.txt"))
need_run <- function(job) { cat(job, "\n", sep = "", file = REQ, append = TRUE)
  stop(structure(class = c("need_run", "error", "condition"), list(message = paste("need", job), call = NULL))) }
read_run <- function(name, S) { f <- file.path(RO, "runs", paste0(name, ".rds")); if (!file.exists(f)) return(NULL)
  x <- readRDS(f); if (is.null(x$finished) || is.null(x$stand$elasticity) || !isTRUE(all.equal(sort(x$node_times), S, tolerance = 0))) return(NULL); x }
summ <- function(cs, x, map) { m <- NULL
  if (map) { mm <- map_by_era(cs, x); m <- setNames(rep(0, 5), MAP_REGIONS); for (g in intersect(names(mm), MAP_REGIONS)) m[g] <- mm[[g]]; m <- c(m, all = mm[["all"]]) }
  list(q = qv(x), rows = x$stand$rows, times = x$stand$times, map = m, cpu = x$stand$cpu + (if (is.null(x$sweep_cpu)) 0 else x$sweep_cpu)) }
prep <- function(cs, S, name) { saveRDS(S, file.path(RO, "sched", paste0(name, ".rds")))
  saveRDS(drop_set(cs, S)$coarse, file.path(RO, "sched", paste0(name, "_coarse.rds"))) }
# The tool's backend for one case at one tolerance. At 1e-4 E6's own runs serve S0 and S1
# when no map is needed; every other run is a map run on the scratch build.
backend <- function(cs, tol) { e6 <- e6_runs(cs)
  function(S, map = TRUE) { S <- sort(S)
    if (tol == 1e-4 && !map) { if (identical(S, e6$S0)) return(summ(cs, e6$x0, FALSE)); if (identical(S, e6$S1)) return(summ(cs, e6$x1, FALSE)) }
    nm <- rf_name(cs, tol, S); x <- read_run(nm, S)
    if (is.null(x)) { prep(cs, S, nm); need_run(sprintf("map/%s/%s/%g", nm, cs, tol)) }
    summ(cs, x, map) } }
case_of_refine <- function(cs, tol = 1e-4) { e6 <- e6_runs(cs); p <- pilot_of(cs); et <- edge_table(cs)
  list(name = cs, S0 = e6$S0, S1 = e6$S1, edges = et[, c("b", "opening")], b1 = p$b1, eps = EPS, run = backend(cs, tol)) }

# The uniform alternative: E6's check rule applied k times (a09's fill at h/1.6^k over level
# k - 1's build, late edges out, inset 12/1.6^k d). k = 1 is E6's check.
un_sched <- function(cs, k) { p <- pilot_of(cs); h <- alg$hfun_of(p); r <- 1.6
  Sc <- build_graded(p, h)
  for (j in seq_len(k)) Sc <- alg$fill(p, function(b) h(b) / r^(j - 1), Sc, build_graded(p, function(b) h(b) / r^j))
  as.numeric(inset_rule(late_out(Sc, p), cs, d = 12 / r^k)) }
un_run <- function(cs, tol, k) { if (k == 1 && tol == 1e-4) return(summ(cs, e6_runs(cs)$x1, FALSE))
  S <- sort(un_sched(cs, k)); if (k == 1) return(backend(cs, tol)(S, FALSE))
  nm <- un_name(cs, tol, k); x <- read_run(nm, S)
  if (is.null(x)) { saveRDS(S, file.path(RO, "sched", paste0(nm, ".rds"))); need_run(sprintf("plain/%s/%s/%g", nm, cs, tol)) }
  summ(cs, x, FALSE) }

# References and their own move (max over quantities, eps): the bank's lib19-class unless a
# held-out-recipe rung exists here; held-out u215 -> u429, or u429 -> u857 where built.
RF_RUN <- function(nm) { f <- file.path(RO, "runs", paste0(nm, ".rds")); if (file.exists(f)) { x <- readRDS(f); if (!is.null(x$finished)) x } }
ref_ladder <- function(cs) {
  rung <- function(n) { x <- RF_RUN(sprintf("ref_%s_u%d", cs, n)); if (is.null(x)) x <- HO_RUN(sprintf("ref_%s_u%d", cs, n))
    if (is.null(x) && n < 857 && !(cs %in% names(CASES))) { f <- file.path(AR, sprintf("ref_%s_u%d.rds", cs, n)); if (file.exists(f)) x <- readRDS(f) }
    if (!is.null(x)) qv(x) }
  u <- lapply(c(u215 = 215, u429 = 429, u857 = 857), rung); u <- u[!vapply(u, is.null, TRUE)]
  if (!is.null(u$u857) && !is.null(u$u429)) return(list(ref = extrap(u$u429, u$u857), own = (u$u857 - u$u429) / 3 / EPS, rungs = "u429-u857"))
  if (cs %in% BANK && !(cs == "episodic-lma" && !is.null(u$u429) && !is.null(u$u215))) {
    f <- if (!is.null(CASES[[cs]])) REF_FILES[[cs]] else file.path(AR, sprintf("ref_%s_u%d.rds", cs, c(215, 429)))
    a <- qv(readRDS(f[1])); b <- qv(readRDS(f[2])); return(list(ref = extrap(a, b), own = (b - a) / 3 / EPS, rungs = "bank")) }
  list(ref = extrap(u$u215, u$u429), own = (u$u429 - u$u215) / 3 / EPS, rungs = "u215-u429") }
