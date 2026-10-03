# Q3, the ordering: the birth-date field builds by the path they took in the spread
# ladder runs (ORDER=2, the sort), per phase (the probe's tallies are cumulative within a
# process), and the forward-only runs under the walk (ORDER=0) and the tolerance
# (ORDER=1, 1e-2 m) against the ladder's sorted forward: CPU per row and J.
#   Rscript order_report.R
N <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pf_nodes"
run <- function(name) { f <- file.path(N, "runs", paste0(name, ".rds")); if (file.exists(f)) readRDS(f) }
rows_of <- function(x) {
  b <- sort(x$stand$nodes$birth)
  sum(findInterval(x$stand$times[-1] - x$stand$sizes[-1], b))
}
counts <- c("builds", "ordered", "node_disorder", "boundary_disorder", "fixed", "walked")
tallies <- function(x) {
  prev <- list(double = setNames(numeric(length(counts)), counts), active = setNames(numeric(length(counts)), counts))
  for (ph in names(x$phases)) {
    t <- x$phases[[ph]]$tally
    if (is.null(t)) next
    for (type in c("double", "active")) {
      tt <- t[[type]]
      now <- vapply(counts, function(k) as.numeric(tt[[k]]), 0)
      inc <- now - prev[[type]]; prev[[type]] <- now
      if (inc[["builds"]] == 0) next
      cat(sprintf("   %-17s %-6s builds %9.0f: ordered %5.1f%%, node pairs out %5.2f%%, boundary out %5.2f%%, sorted %5.2f%%, walked %5.2f%%\n",
                  ph, type, inc[["builds"]], 100 * inc[["ordered"]] / inc[["builds"]],
                  100 * inc[["node_disorder"]] / inc[["builds"]], 100 * inc[["boundary_disorder"]] / inc[["builds"]],
                  100 * inc[["fixed"]] / inc[["builds"]], 100 * inc[["walked"]] / inc[["builds"]]))
    }
  }
  t <- x$phases[[length(x$phases)]]$tally$double
  if (!is.null(t)) {
    cat(sprintf("   largest inversion: node %.3g m, boundary %.3g m; out of order from t = %.3g to %.3g; most pairs in one build %d\n",
                t$max_node_inversion, t$max_boundary_inversion, t$first_time, t$last_time, t$most_pairs))
    cat("   largest inversion per build by decade (<1e-7 ... >=1e-1 m): node", t$node_hist, "| boundary", t$boundary_hist, "\n")
  }
}

for (name in c("wet_D_u108", "wet_D_u215", "wet_D_u429", "wet_BD_G1", "wet_BD_G2", "wet_BD_G3",
               "ld_D_u108", "ld_D_u215", "ld_D_u429")) {
  x <- run(name)
  if (is.null(x) || is.null(x$finished)) next
  cat(sprintf("== %s (%d nodes, %.0f rows)\n", name, length(x$stand$nodes$birth), rows_of(x)))
  tallies(x)
  ph <- x$phases
  cat(sprintf("   cpu s: forward %.0f (%.3f ms per row), stand sweep %.0f, invader walk %.0f, invader sweep %.0f\n",
              ph$stand_run$cpu, 1e3 * ph$stand_run$cpu / rows_of(x), ph$stand_gradient$cpu,
              ph$invader_run$cpu, ph$invader_gradient$cpu))
}

cat("\n== forward only: walk (0) and tolerance (1) against the ladder's sort (2)\n")
for (n in c("u215", "u429")) {
  s <- run(sprintf("wet_D_%s", n))
  if (is.null(s)) next
  for (o in c("o1", "o0")) {
    x <- run(sprintf("wet_D_%s_%s", n, o))
    if (is.null(x) || is.null(x$finished)) next
    cat(sprintf("   D %s %s: cpu %.0f s against %.0f (%+.1f%%), per row %+.1f%%; J/J_sort - 1 = %+.2e; steps %d against %d\n",
                n, o, x$phases$stand_run$cpu, s$phases$stand_run$cpu,
                100 * (x$phases$stand_run$cpu / s$phases$stand_run$cpu - 1),
                100 * ((x$phases$stand_run$cpu / rows_of(x)) / (s$phases$stand_run$cpu / rows_of(s)) - 1),
                x$stand$J / s$stand$J - 1, length(x$stand$times), length(s$stand$times)))
    tallies(x)
  }
}
