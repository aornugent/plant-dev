# Phase 3 baselines: the incumbent hybrid loop from dy, scored from its stored runs, and
# the first lattice algorithm, one point certified by its coarsening.
source("/home/user/plant-dev/harness/schedule/evaluate.R")

# The incumbent: the pilot, then each pass's H and C with gradients, until the ln J
# estimate is under eps/2; it reports H. Rows from each stored run.
incumbent <- function(case, tag = c(`episodic-lma` = "dylma")[case]) {
  tag <- if (is.na(tag)) "dy" else tag; rec <- CASES[[case]]$rec
  pilot <- readRDS(file.path(RUNS, paste0(CASES[[case]]$pilot, ".rds")))
  spent <- run_cost(sum(findInterval(pilot$stand$times[-length(pilot$stand$times)], sort(pilot$stand$nodes$birth))), FALSE)
  last <- NULL
  for (p in 0:5) { h <- rd(file.path(ADJ, sprintf("hybl_%s_%s_p%d.rds", tag, rec, p))); cc <- rd(file.path(ADJ, sprintf("hyblC_%s_%s_p%d.rds", tag, rec, p)))
    if (is.null(h)) break
    spent <- spent + run_cost(h$stand$rows) + if (!is.null(cc)) run_cost(cc$stand$rows) else 0; last <- list(h = h, c = cc) }
  ref <- reference(case); q <- quantities(last$h); k <- intersect(names(q), names(ref)); e <- eps_vec(k)
  err <- (q[k] - ref[k]) / e
  data.frame(case = case, T = spent + K_USE * run_cost(last$h$stand$rows), T_find = spent, T_use = run_cost(last$h$stand$rows), worst = max(abs(err)), C1 = all(abs(err) <= 1))
}

# One lattice point, certified by its coarsening in both regions; reports the
# extrapolation.
one_point <- function(f = 16, l = 70) { force(f); force(l); function(ctx) {
  a <- ctx$run(f, l); b <- ctx$run(f / 2, l * 2)
  k <- intersect(names(a$q), names(b$q))
  list(use = list(c(f, l)), answer = a$q[k], estimate = (a$q[k] - b$q[k]) / 3) } }
