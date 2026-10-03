# Which existing runs are plant's own adaptive runs, on which library, with which
# introductions and settings: the candidates for the combined setting's baselines.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
u108 <- readRDS(file.path(D, "window/t/t_u108.rds"))
uniform <- seq(0, 107 * 40 / 108, length.out = 108)
cat("t_u108.rds identical to uniform_times(108):", identical(u108, uniform), "; max diff", max(abs(u108 - uniform)), "\n")
files <- c(file.path(WT, "docs/measurements/spot-check", c("ld_3e-5.rds", "ld_2.85e-5.rds", "ld_3.15e-5.rds",
                                                           "wet_base.rds", "wet_tol.rds", "epi_base.rds", "epi_tol.rds")),
           file.path(WT, "docs/measurements/nudges", c("ld_1e-5.rds", "ld_9.5e-6.rds", "ld_1.05e-5.rds")),
           file.path(D, "phase1c/full/epi_1e-5.rds"),
           file.path(D, "window/runs", c("win_long-drought_u108.rds", "win_long-wet_u108.rds", "win_episodic_u108.rds")))
for (f in files) {
  if (!file.exists(f)) { cat(basename(f), ": missing\n"); next }
  x <- readRDS(f)
  s <- x$setting; v <- x$versions
  nt <- if (!is.null(x$node_times)) x$node_times else NULL
  cat(sprintf("%-28s lib %-12s plant %-12s tol %-8s abs %-8s nodes %s program '%s' | node times = u108: %s | invaders: %s | elasticities: %s | started %s\n",
              basename(f), if (is.null(v$lib)) "?" else basename(v$lib), if (is.null(v$plant)) "?" else v$plant,
              format(if (is.null(s$tol)) x$tol else s$tol), format(if (is.null(s$tol_abs)) x$tol_abs else s$tol_abs),
              format(if (is.null(s$nodes)) x$nodes else s$nodes), if (is.null(s$program)) "" else s$program,
              if (is.null(nt)) "?" else identical(nt, u108), paste(names(x$invaders), collapse = ","),
              !is.null(x$stand$elasticity), if (is.null(x$started)) "?" else x$started))
}
