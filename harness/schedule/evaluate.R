# Offline evaluator of plan-schedule-search.md: replays a scheduling algorithm on each
# training case against stored lattice runs and scores T = T_find + k T_use and the
# constraints C1-C4. Algorithms are functions of one argument, the case's context.
source("/home/user/plant-dev/harness/schedule/lattice.R")
ADJ <- file.path(DEV, "schedtest/adjmap/runs")
K_USE <- 2
SEC_PER_ROW <- 113e-6     # forward CPU per row; a sweep costs 3.27 forwards
SWEEP <- 3.27

eps_tab <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps_of <- function(trait) {
  e <- eps_tab$eps[eps_tab$role == "resident" & eps_tab$trait == trait & eps_tab$unit != "curvature in lma"]
  max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE)
}
EXCLUDED <- c("S_D", "a_f3", "recruitment_decay")
quantities <- function(x) {
  e <- unname(x$stand$elasticity); names(e) <- sub("^1\\.", "", names(x$stand$elasticity))
  c(lnJ = log(x$stand$J), e[!names(e) %in% EXCLUDED])
}
eps_vec <- function(q) vapply(q, function(n) if (n == "lnJ") 0.025 else eps_of(n), 0)
rd <- function(f) if (file.exists(f)) readRDS(f)
extrap <- function(m, f) f + (f - m) / 3

# References: two uniform levels extrapolated on the square law.
NR <- file.path(DEV, "node_rule/ladder/runs"); PL <- file.path(DEV, "schedtest/placement/runs"); PF <- file.path(DEV, "pf_nodes/runs")
REF_FILES <- list(episodic = c(file.path(NR, "u429_episodic.rds"), file.path(PL, "u857_episodic.rds")),
  dry = c(file.path(NR, "u215_dry.rds"), file.path(NR, "u429_dry.rds")),
  `long-wet` = c(file.path(NR, "u215_long-wet.rds"), file.path(NR, "u429_long-wet.rds")),
  `long-drought` = c(file.path(PF, "ld_D_u215.rds"), file.path(PF, "ld_D_u429.rds")),
  `episodic-lma` = c(file.path(RUNS, "m_lma1252_episodic.rds"), file.path(RUNS, "m_lma1254_episodic.rds")))
reference <- function(case) { r <- REF_FILES[[case]]; a <- quantities(readRDS(r[1])); b <- quantities(readRDS(r[2])); k <- intersect(names(a), names(b)); extrap(a[k], b[k]) }

run_cost <- function(rows, gradient = TRUE) rows * SEC_PER_ROW * (1 + if (gradient) SWEEP else 0)

# The case's library: every stored lattice point, with its quantities and cost.
load_library <- function(case) {
  fs <- list.files(ADJ, sprintf("^lat_%s_f[0-9]+_l[0-9.]+\\.rds$", gsub("-", "\\\\-", case)), full.names = TRUE)
  pts <- list()
  for (f in fs) { x <- readRDS(f); if (is.null(x$stand$elasticity)) next
    m <- regmatches(basename(f), regexec("_f([0-9]+)_l([0-9.]+)\\.rds$", basename(f)))[[1]]
    pts[[sprintf("%s/%s", m[2], m[3])]] <- list(f = as.numeric(m[2]), l = as.numeric(m[3]), q = quantities(x), rows = x$stand$rows) }
  pts
}

# A lattice point's answer: stored if run, otherwise by additivity of the founders' and
# late regions about the centre (16, 70). Its cost is that of the run it stands for.
lookup <- function(lib, f, l, f0 = 16, l0 = 70) {
  key <- function(a, b) sprintf("%s/%s", format(a), format(b))
  if (!is.null(p <- lib[[key(f, l)]])) return(list(q = p$q, rows = p$rows, exact = TRUE))
  a <- lib[[key(f, l0)]]; b <- lib[[key(f0, l)]]; c0 <- lib[[key(f0, l0)]]
  if (is.null(a) || is.null(b) || is.null(c0)) return(NULL)
  k <- Reduce(intersect, list(names(a$q), names(b$q), names(c0$q)))
  list(q = a$q[k] + b$q[k] - c0$q[k], rows = a$rows + b$rows - c0$rows, exact = FALSE)
}

# Run one algorithm on one case. The algorithm calls ctx$run(f, l, gradient) for each
# schedule it wants (charged to T_find), reads ctx$pilot, and returns
# list(use = list of c(f, l), answer = named quantities, estimate = named |error|
# estimates). `use` is every point one later use needs: two when the answer is an
# extrapolation.
CACHE <- new.env()
cached <- function(key, f) { if (is.null(CACHE[[key]])) CACHE[[key]] <- f(); CACHE[[key]] }
evaluate_case <- function(alg, case, lib = cached(paste0("lib:", case), function() load_library(case)), ref = cached(paste0("ref:", case), function() reference(case))) {
  spent <- 0; path <- c()
  pilot <- cached(paste0("pilot:", case), function() readRDS(file.path(RUNS, paste0(CASES[[case]]$pilot, ".rds"))))
  spent <- spent + run_cost(sum(findInterval(pilot$stand$times[-length(pilot$stand$times)], sort(pilot$stand$nodes$birth))), FALSE)
  ctx <- list(case = case, pilot = c(cached(paste0("edges:", case), function() pilot_edges(case)), list(J = pilot$stand$J)), eps = eps_vec,
    pilot_nodes = data.frame(birth = pilot$stand$nodes$birth, nrr = pilot$stand$nodes$nrr),
    run = function(f, l, gradient = TRUE) {
      if (!(f >= 8 && f <= 128 && l >= 8.75 && l <= 140)) stop(sprintf("point (%s, %s) outside f 8-128, l 8.75-140", f, l))
      f <- round(f); p <- lookup(lib, f, l); if (is.null(p)) stop(sprintf("no library point (%s, %s) for %s", f, l, case))
      key <- sprintf("%s/%s/%s", f, l, gradient); full <- sprintf("%s/%s/TRUE", f, l)
      if (!(key %in% path) && !(full %in% path)) { spent <<- spent + run_cost(p$rows, gradient); path <<- c(path, key) }
      if (!gradient) p$q <- p$q["lnJ"]; p })
  out <- alg(ctx)
  t_use <- sum(vapply(out$use, function(u) run_cost(lookup(lib, round(u[1]), u[2])$rows), 0))
  k <- Reduce(intersect, list(names(out$answer), names(ref), names(out$estimate)))
  e <- eps_vec(k); err <- (out$answer[k] - ref[k]) / e; est <- abs(out$estimate[k]) / e
  big <- abs(err) > 1 / 3
  list(case = case, T_find = spent, T_use = t_use, T = spent + K_USE * t_use,
    worst = max(abs(err)), C1 = all(abs(err) <= 1), C2 = all(est[abs(err) > 0.5] > 0.25),
    C3 = if (any(big)) mean(est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big])) >= 0.8 else TRUE,
    path = paste(path, collapse = " > "), err = err, est = est)
}

evaluate <- function(alg, cases = names(CASES)) {
  res <- lapply(cases, function(cs) tryCatch(evaluate_case(alg, cs), error = function(e) list(case = cs, error = conditionMessage(e))))
  tab <- do.call(rbind, lapply(res, function(r) if (!is.null(r$error)) data.frame(case = r$case, T = NA, T_find = NA, T_use = NA, worst = NA, C1 = FALSE, C2 = FALSE, C3 = FALSE, path = r$error) else
    data.frame(case = r$case, T = r$T, T_find = r$T_find, T_use = r$T_use, worst = r$worst, C1 = r$C1, C2 = r$C2, C3 = r$C3, path = r$path)))
  list(table = tab, T = sum(tab$T), feasible = all(tab$C1 & tab$C2 & tab$C3, na.rm = FALSE), detail = res)
}
