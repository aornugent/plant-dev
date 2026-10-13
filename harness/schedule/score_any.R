# Score one schedule-building algorithm on the training bank against the any-schedule scorer.
#   Rscript harness/schedule/score_any.R ALGORITHM.R [TAG]      (STRESS=n draws, 20 by default)
# ALGORITHM.R defines `algorithm <- function(ctx)`. ctx gives:
#   ctx$pilot: b1 (end of the founders' window), edges (birth dates where establishment
#     opens or shuts; every schedule must contain them), shut(b) (1 while shut), J,
#     creation (start, end, rate: the pilot's establishment record), nodes (the pilot's 54
#     nodes: birth, nrr, height, mortality), soil. The pilot is already paid for.
#   ctx$run(S, gradient = TRUE, drop = NULL): a run on birth dates S (increasing, from 0,
#     below ctx$horizon = 39.6). Returns q (ln J and the elasticities; ln J only when
#     gradient = FALSE, at a quarter of the cost) and rows. With `drop` (indices into S of
#     nodes with a neighbour each side), it also returns map: per dropped node, the move
#     of ln J were that node removed, for 5.4% more. Repeats are free.
#   ctx$eps(names): each quantity's eps. rooting_depth_max is not among the quantities.
#   The scorer's range: every pilot edge is a node; open intervals at most b1/12 in the
#   founders' window, 100 d before b = 20, 280 d after. Outside it, the run refuses.
# It returns list(use = list(S, ...), answer = named quantities, estimate = signed error
# estimates); `use` holds the schedules one later use needs.
# T = T_find + 2 T_use summed over cases, CPU seconds. Feasible when on every case:
# C1 every |error| <= eps; C2 every error over eps/2 has |estimate| over eps/4; C3 for 80%
# of quantities whose error or estimate exceeds eps/3, the estimate is within x2 with the
# error's sign; C5 every |estimate| <= eps. Robust: feasible on all STRESS draws, each run
# carrying the scorer's own miss for that quantity plus 0.04 eps of run-to-run jitter.
source("/home/user/plant-dev/harness/schedule/anyscore.R")
a <- commandArgs(TRUE); env <- new.env(); sys.source(a[1], env)
alg <- function(ctx) env$algorithm(ctx)
draws <- as.integer(Sys.getenv("STRESS", "20")); ok <- c(); tot <- c()
for (d in seq_len(draws)) { STRESS <<- d; rr <- evaluate_any(alg); ok <- c(ok, rr$feasible); tot <- c(tot, rr$T) }
STRESS <<- 0; r <- evaluate_any(alg)
tab <- r$table; tab$T <- round(tab$T); tab$T_find <- round(tab$T_find); tab$T_use <- round(tab$T_use); tab$worst <- round(tab$worst, 2)
print(tab, row.names = FALSE, right = FALSE)
for (dd in r$detail) if (is.null(dd$error)) { o <- order(-abs(dd$err))[1:3]
  cat(sprintf("  %-13s largest errors: %s\n", dd$case, paste(sprintf("%s %+.2f (est %+.2f)", names(dd$err)[o], dd$err[o], dd$est[o]), collapse = ", "))) }
cat(sprintf("TOTAL T = %.0f s, feasible = %s\n", r$T, r$feasible))
if (draws > 0) cat(sprintf("ROBUST: feasible on %d of %d draws, T %.0f-%.0f\n", sum(ok), draws, min(tot), max(tot)))
log <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/leaderboard_any.tsv"
cat(sprintf("%s\t%s\t%s\t%.0f\t%s\t%d/%d\t%.0f\n", format(Sys.time(), "%H:%M:%S"), if (length(a) > 1) a[2] else "-", normalizePath(a[1]), r$T, r$feasible, sum(ok), draws, if (draws) max(tot) else NA), file = log, append = TRUE)
