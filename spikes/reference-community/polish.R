# Chord-Newton polish of a one-shot root with the measured Jacobian J of g
# along the equilibrium (classify_<RUN>_h<H>.rds): from the last saved step,
#   dx = -J^-1 g,  d ln b = -(F + F_theta dx) / F_lnb,
# one recording per step, saved as further step files.
#   RUN=closed3b ITERS=2 Rscript polish.R
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
RUN <- Sys.getenv("RUN", "closed3b")
RUN_DIR <- file.path(TMP, "runs", RUN)
H_STEP <- as.numeric(Sys.getenv("H_STEP", "0.01"))
# J from the classification taken at step CLASSIFY_STEP.
cdir <- file.path(RUN_DIR, sprintf("classify_h%g_s%d", H_STEP,
                                   as.integer(Sys.getenv("CLASSIFY_STEP", "10"))))
cl <- list(J = sapply(seq_along(EVOLVE), function(i)
  (drop(readRDS(file.path(cdir, sprintf("J_%d_+1.rds", i)))$g) -
     drop(readRDS(file.path(cdir, sprintf("J_%d_-1.rds", i)))$g)) / (2 * H_STEP)))
ITERS <- as.integer(Sys.getenv("ITERS", "2"))
CAP <- as.numeric(Sys.getenv("RADIUS", "0.2"))
for (it in seq_len(ITERS)) {
  steps <- sort(list.files(RUN_DIR, "^step_[0-9]+\\.rds$"))
  r <- readRDS(file.path(RUN_DIR, tail(steps, 1)))
  n <- as.integer(sub("step_([0-9]+).rds", "\\1", tail(steps, 1)))
  g <- drop(r$g)
  d <- -drop(solve(cl$J, g))
  if (max(abs(d)) > CAP) d <- d * CAP / max(abs(d))
  dlnb <- -(r$F + sum(drop(r$F_theta) * d)) / r$F_lnb[1, 1]
  cat(sprintf("from step %d: F %+.2e g %s -> dx %s dlnb %+.5f\n", n, r$F,
              paste(sprintf("%+.4f", g), collapse = " "),
              paste(sprintf("%+.5f", d), collapse = " "), dlnb))
  q <- record(r$lnb + dlnb, drop(r$x) + d,
              file = file.path(RUN_DIR, sprintf("step_%03d.rds", n + 1)))
  cat(sprintf("step %d: lnb %.6f x %s F %+.2e g %s (%.0fs)\n", n + 1, q$lnb,
              paste(sprintf("%+.5f", drop(q$x)), collapse = " "), q$F,
              paste(sprintf("%+.4f", drop(q$g)), collapse = " "), q$secs_run + q$secs_sweep))
}
