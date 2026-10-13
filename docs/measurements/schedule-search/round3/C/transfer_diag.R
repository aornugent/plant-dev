# What the pilots say about each trait move: edges kept, J, the founders' layer and the
# proxy's error of theta0's committed schedule under each pilot.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/base.R", A <- new.env())
source("/home/user/plant-dev/harness/schedule/lattice.R")
pil <- function(case) { cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
  list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, J = px$J, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")])) }
near <- function(a, b, tol = 1e-3) mean(vapply(a, function(x) min(abs(b - x)) < tol, TRUE))
for (pr in list(c("episodic", "episodic-lma"), c("dry", "dry-p50"), c("long-wet", "wet-adG2"))) {
  p0 <- pil(pr[1]); p1 <- pil(pr[2]); S0 <- build_graded(p0, A$hfun_of(p0)); S1 <- build_graded(p1, A$hfun_of(p1))
  f0 <- p0$nodes$nrr[p0$nodes$birth < p0$b1]; f1 <- p1$nodes$nrr[p1$nodes$birth < p1$b1]
  cat(sprintf("%s -> %s: edges %d/%d (within 1e-3: %.2f), b1 %.2f/%.2f, J %.3g/%.3g, layer end %.2f/%.2f, founders' offspring drop %.0f/%.0f\n", pr[1], pr[2],
    length(p0$edges), length(p1$edges), near(p1$edges, p0$edges), p0$b1, p1$b1, p0$J, p1$J, A$layer_end(p0), A$layer_end(p1), f0[1] / tail(f0, 1), f1[1] / tail(f1, 1)))
  cat(sprintf("   proxy error of S0 under pilot1/pilot0: %.2f; S1 under pilot1 / S0 under pilot0: %.2f; nodes %d/%d, S1 within 1e-3 of S0: %.2f\n",
    A$proxy_err(p1, S0) / A$proxy_err(p0, S0), A$proxy_err(p1, S1) / A$proxy_err(p0, S0), length(S0), length(S1), near(S1, S0))) }
