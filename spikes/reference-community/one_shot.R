# The one-shot solve of (F, g) = 0 for one TF24 resident: one recording per
# step. Traits take a Broyden step on g, restarted to steepest ascent when a
# step would go against selection, capped at RADIUS in every ln trait (halved
# when a step overshoots, doubled back toward the cap when it does not); ln b
# takes Newton's step predicted along the trait step through F_theta.
#
#   RUN=closed LNB0=3.595 X0=0,0,0 Rscript one_shot.R
#
# Every step's recording is saved as <RUN_DIR>/step_NNN.rds, and the solver
# state as state.rds, so a restart resumes from the last saved step.
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
RUN <- Sys.getenv("RUN", "closed")
RUN_DIR <- file.path(TMP, "runs", RUN)
dir.create(RUN_DIR, recursive = TRUE, showWarnings = FALSE)
k <- length(EVOLVE)
num <- function(v, d) {
  s <- Sys.getenv(v)
  if (nzchar(s)) as.numeric(strsplit(s, ",")[[1]]) else d
}
CAP <- num("RADIUS", 0.1)
TOL_F <- num("TOL_F", 1e-6)
TOL_G <- num("TOL_G", 0.02)
MAX_STEPS <- num("MAX_STEPS", 40)

state_file <- file.path(RUN_DIR, "state.rds")
st <- if (file.exists(state_file)) readRDS(state_file) else
  list(lnb = num("LNB0", 3.595), x = num("X0", rep(0, k)), B = NULL,
       s = NULL, g = NULL, radius = CAP, n = 0, log = list())

broyden_step <- function(st, g) {
  scale <- max(abs(g)) / st$radius  # steepest ascent reaches the radius
  if (is.null(st$B)) st$B <- -diag(scale, k)
  if (!is.null(st$s) && sum(st$s^2) > 0) {
    r <- g - st$g - drop(st$B %*% st$s)
    st$B <- st$B + outer(r, st$s) / sum(st$s^2)
  }
  d <- -solve(st$B, g)
  restart <- sum(d * g) <= 0
  if (restart) {
    st$B <- -diag(scale, k)
    d <- g / scale
  }
  big <- max(abs(d))
  if (big > st$radius) d <- d * st$radius / big
  list(st = st, d = d, restart = restart)
}

while (st$n < MAX_STEPS) {
  st$n <- st$n + 1
  f <- file.path(RUN_DIR, sprintf("step_%03d.rds", st$n))
  r <- record(st$lnb, st$x, file = f)
  g <- drop(r$g)
  # A step whose g reverses and grows has overshot: shrink the radius.
  if (!is.null(st$g)) {
    if (sum(g * st$g) < 0 && sqrt(sum(g^2)) > sqrt(sum(st$g^2))) {
      st$radius <- st$radius / 2
    } else if (length(st$s) && max(abs(st$s)) >= 0.99 * st$radius) {
      st$radius <- min(CAP, 2 * st$radius)
    }
  }
  done <- abs(r$F) < TOL_F && max(abs(g)) < TOL_G
  b <- if (done) list(st = st, d = rep(0, k), restart = FALSE) else broyden_step(st, g)
  d <- if (max(abs(g)) < TOL_G) rep(0, k) else b$d
  dlnb <- -(r$F + sum(r$F_theta * d)) / r$F_lnb[1, 1]
  st$log[[st$n]] <- list(step = st$n, lnb = st$lnb, x = st$x, F = r$F, g = g,
                         F_lnb = r$F_lnb[1, 1], F_theta = drop(r$F_theta),
                         d = d, dlnb = dlnb, radius = st$radius,
                         restart = b$restart, secs = r$secs_run + r$secs_sweep,
                         steps = r$steps)
  cat(sprintf("%3d lnb %.6f x %s | F %+.2e g %s | d %s %s r %.3f %.0fs\n",
              st$n, st$lnb, paste(sprintf("%+.5f", st$x), collapse = " "), r$F,
              paste(sprintf("%+.4f", g), collapse = " "),
              paste(sprintf("%+.4f", d), collapse = " "),
              if (b$restart) "SD" else "  ", st$radius,
              r$secs_run + r$secs_sweep))
  if (done) { saveRDS(st, state_file); break }
  st$B <- b$st$B  # keep the log: b$st predates this step's entry
  st$s <- d
  st$g <- g
  st$x <- st$x + d
  st$lnb <- st$lnb + dlnb
  saveRDS(st, state_file)
}
