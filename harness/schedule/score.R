# Score one scheduling algorithm on the training bank, in seconds, against the surrogate.
#   Rscript harness/schedule/score.R ALGORITHM.R [TAG]
# ALGORITHM.R defines `algorithm <- function(ctx)`. ctx gives:
#   ctx$run(f, l, gradient = TRUE): a run with f founders' nodes (integer, 8-128) and late
#     spacing l days (8.75-140); returns list(q = named quantities, rows). A forward run
#     (gradient = FALSE) returns only q["lnJ"] and costs a quarter as much. Repeats are free.
#   ctx$eps(names): each quantity's eps.
#   ctx$pilot: b1 (end of the founders' window, years), edges (birth dates), J; and
#     ctx$pilot_nodes: the pilot's 54 nodes (birth, nrr). The pilot is already paid for.
# It returns list(use = list(c(f, l), ...), answer = named quantities, estimate = named
# error estimates). `use` lists every run one later use of the answer needs.
# Target: T = T_find + 2 T_use summed over cases, in CPU seconds; feasible when on every
# case every quantity is within eps (C1), every error over eps/2 has an estimate over
# eps/4 (C2), and estimates are within x2 for 80% of the quantities whose error or estimate
# exceeds eps/3 (C3). The answer must come from the runs in `use`. STRESS=n also scores n
# draws with each off-lattice point given its own real-run jitter (rms 0.04 eps, heavy
# tail), 20 by default; STRESS=0 skips it. A candidate counts as feasible only when it
# is feasible on every draw, and its T is the largest over the draws.
suppressMessages(source("/home/user/plant-dev/harness/schedule/surrogate.R"))
a <- commandArgs(TRUE); env <- new.env(); sys.source(a[1], env)
alg <- function(ctx) { ctx$case <- NULL; env$algorithm(ctx) }
orig_run_guard <- function(f, l) f >= 8 && f <= 128 && l >= 8.75 && l <= 140
draws <- as.integer(Sys.getenv("STRESS", "20"))
if (draws > 0) { ok <- c(); tot <- c()
  for (d in seq_len(draws)) { STRESS <<- d; for (n in ls(CACHE, pattern = "^fit:")) NULL; rr <- evaluate(alg); ok <- c(ok, rr$feasible); tot <- c(tot, rr$T) }
  cat(sprintf("STRESS %d draws (off-lattice points with measured real-run jitter): feasible in %d, T %.0f-%.0f\n", draws, sum(ok), min(tot), max(tot))); STRESS <<- 0
  robust <- all(ok); robust_T <- max(tot) }
r <- evaluate(alg)
tab <- r$table; tab$T <- round(tab$T); tab$T_find <- round(tab$T_find); tab$T_use <- round(tab$T_use); tab$worst <- round(tab$worst, 3)
print(tab, row.names = FALSE, right = FALSE)
for (d in r$detail) if (is.null(d$error)) { o <- order(-abs(d$err))[1:3]
  cat(sprintf("  %-13s largest errors: %s\n", d$case, paste(sprintf("%s %+.2f (est %.2f)", names(d$err)[o], d$err[o], d$est[o]), collapse = ", "))) }
cat(sprintf("TOTAL T = %.0f s, feasible = %s\n", r$T, r$feasible))
if (draws > 0) cat(sprintf("ROBUST: feasible on all %d draws = %s, T = %.0f\n", draws, robust, robust_T))
log <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/leaderboard.tsv"
cat(sprintf("%s\t%s\t%s\t%.0f\t%s\t%.3f\t%s\n", format(Sys.time(), "%H:%M:%S"), if (length(a) > 1) a[2] else "-", normalizePath(a[1]), r$T, r$feasible, max(tab$worst, na.rm = TRUE), if (draws > 0) sprintf("robust=%s T=%.0f", robust, robust_T) else "robust=NA"), file = log, append = TRUE)
