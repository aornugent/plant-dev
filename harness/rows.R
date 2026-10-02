# What a driver run costs a gradient run: its forward's member evaluations,
# rejected attempts included, and its rows, the members on each accepted step,
# which the invader's walk and both sweeps pay again. A gradient run is one
# forward, a sweep of 2.6 forwards, a walk of 0.8 and its sweep of 2.6, so
# against the first file its cost is (forward + 6 rows) / 7.
#
#   [JSTAR=12.6687135] Rscript harness/rows.R base.rds run.rds ...
#
# Each file is harness/ark_prototype.R's OUT.
args <- commandArgs(TRUE)
jstar <- as.numeric(Sys.getenv("JSTAR", NA))
runs <- lapply(args, readRDS)
fwd <- vapply(runs, function(r) r$counts$members, 0)
rows <- vapply(runs, function(r) sum(as.numeric(r$st$M)), 0)
out <- data.frame(run = sub("\\.rds$", "", basename(args)),
                  tol = vapply(runs, `[[`, 0, "tol"),
                  accepted = vapply(runs, function(r) nrow(r$st), 0),
                  rows = rows, forward = fwd,
                  err = sprintf("%+.2g", vapply(runs, `[[`, 0, "J") / jstar - 1),
                  forward_rel = sprintf("%+.1f%%", 100 * (fwd / fwd[1] - 1)),
                  rows_rel = sprintf("%+.1f%%", 100 * (rows / rows[1] - 1)),
                  gradient_rel = sprintf("%+.1f%%", 100 * ((fwd / fwd[1] + 6 * rows / rows[1]) / 7 - 1)))
if (is.na(jstar)) out$err <- NULL
print(out, row.names = FALSE)
