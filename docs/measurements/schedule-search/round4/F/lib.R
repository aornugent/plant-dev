# Shared loaders for agent F: a case's committed (c) and check (f) runs, its reference,
# eps, the a09 shrink, and real CPU.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max")
R <- AR
OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/F_out"
ALL <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")
LD <- c("long-drought", "ld-102", "ld-105")
alg <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a09_late.R", alg)
pilot_of <- function(case) { cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
  list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")])) }
refq <- function(case) if (!is.null(CASES[[case]])) reference(case) else {
  x <- quantities(readRDS(file.path(R, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(R, sprintf("ref_%s_u429.rds", case))))
  k <- intersect(names(x), names(y)); extrap(x[k], y[k]) }
# a09's runs in the proper setting: long-drought records from the a09p rerun.
tag_of <- function(tag, case) if (tag == "a09" && case %in% LD) "a09p" else tag
rd_run <- function(tag, side, case) { f <- file.path(R, sprintf("val_%s_%s_%s.rds", tag_of(tag, case), side, case)); if (file.exists(f)) readRDS(f) }
cpu_of <- function(x) x$stand$cpu + (if (is.null(x$sweep_cpu)) 0 else x$sweep_cpu)
# One case's pair: errors in eps units, the move, the a09 shrink, costs.
pair <- function(case, tag = "a09", shrink = NULL) {
  xc <- rd_run(tag, "c", case); xf <- rd_run(tag, "f", case); if (is.null(xc) || is.null(xf) || is.null(xc$stand$elasticity) || is.null(xf$stand$elasticity)) return(NULL)
  ref <- refq(case); qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k)
  p <- pilot_of(case)
  s <- if (is.null(shrink)) alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times) else shrink
  list(case = case, k = k, e = e, ref = ref[k], qc = qc[k], qf = qf[k], ec = (qc[k] - ref[k]) / e, ef = (qf[k] - ref[k]) / e,
       d = (qc[k] - qf[k]) / e, s = s, xc = xc, xf = xf, p = p,
       Tc = run_cost(xc$stand$rows, TRUE), Tf = run_cost(xf$stand$rows, TRUE), cpu_c = cpu_of(xc), cpu_f = cpu_of(xf)) }
# C1-C5 for a committed error vector and signed estimate (eps units).
crit <- function(err, sest) { est <- abs(sest); big <- pmax(abs(err), est) > 1 / 3
  ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  c(C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25),
    C3 = if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE, C5 = all(est <= 1)) }
