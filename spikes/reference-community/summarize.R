# Collect each regime's reference strategy and the solve history into
# reference_<record>.rds and solve_history.rds, from the saved runs.
#   EARLY=40 EARLY_RATIO=1.1892071150 EVOLVE=lma,hmat,vcmax_25 Rscript summarize.R
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
runs <- file.path(TMP, "runs")
steps_of <- function(run) {
  f <- sort(list.files(file.path(runs, run), "^step_[0-9]+\\.rds$", full.names = TRUE))
  do.call(rbind, lapply(f, function(p) {
    r <- readRDS(p)
    g <- drop(r$g)
    data.frame(run = run, step = as.integer(sub(".*step_([0-9]+)\\.rds", "\\1", p)),
               lnb = r$lnb, t(setNames(drop(r$x), paste0("x.", names(g)))),
               F = r$F, F_lnb = r$F_lnb[1, 1], t(setNames(g, paste0("g.", names(g)))),
               max_g = max(abs(g)), ode_steps = r$steps, secs_run = r$secs_run,
               secs_sweep = r$secs_sweep, check.names = FALSE)
  }))
}
RUNS <- c("closed-rho4", "closed3", "closed3b", "seasonal3", "seasonal3b")
history <- setNames(lapply(RUNS, function(r) tryCatch(steps_of(r), error = function(e) NULL)), RUNS)
saveRDS(history, file.path(HERE, "solve_history.rds"))

# One reference per regime: the polished root, its classification, pricing and
# the 216 + 40 certification. Traits are shifts from the regime's start
# resident (lma 0.32 e^lma_shift, the rest at TF24's defaults).
make_ref <- function(run, step, cl_step, record, label, lma_shift) {
  root <- readRDS(file.path(runs, run, sprintf("step_%03d.rds", step)))
  base <- THETA_BASE
  base[["lma"]] <- LMA0 * exp(lma_shift)
  traits <- base
  traits[EVOLVE] <- base[EVOLVE] * exp(drop(root$x))
  cert_f <- list.files(file.path(TMP, "sched"),
                       sprintf("^%s_n216_e40.*lnb%.4f", record, root$lnb), full.names = TRUE)
  cert <- if (length(cert_f)) readRDS(cert_f[1]) else NULL
  price_f <- file.path(HERE, sprintf("price_%s.rds", run))
  ref <- list(
    regime = label, record = record,
    schedule = list(nodes = NODES, early = EARLY, early_ratio = EARLY_RATIO,
                    introductions = length(TIMES), times = TIMES,
                    ode_tol_rel = TOL, ode_tol_abs = TOL * 1e-4),
    evolving = EVOLVE, base_traits = base, step = step,
    lnb = root$lnb, b = exp(root$lnb), x = drop(root$x), traits = traits,
    F = root$F, F_lnb = root$F_lnb[1, 1], F_theta = drop(root$F_theta), g = drop(root$g),
    classification = readRDS(file.path(HERE, sprintf("classify_%s_h0.01_s%d.rds", run, cl_step))),
    price = if (file.exists(price_f)) readRDS(price_f) else NULL,
    certification_216 = cert)
  saveRDS(ref, file.path(HERE, sprintf("reference_%s.rds", record)))
  cat("==", label, "\n")
  print(ref[c("lnb", "b", "traits", "F", "g")])
  if (!is.null(cert)) cat(sprintf("216+40 at the root: F %+.5f (dF %+.5f), g %s (dg %s)\n",
    cert$F, cert$F - root$F, paste(sprintf("%+.4f", cert$g), collapse = " "),
    paste(sprintf("%+.4f", cert$g - drop(root$g)), collapse = " ")))
  if (!is.null(ref$price)) cat(sprintf("pricing: %d invaders, max ln R' %.2e (resident %.2e)\n",
    length(ref$price$lnR), max(ref$price$lnR), ref$F))
  invisible(ref)
}
make_ref("closed3b", 14, 14, "long-wet", "closed canopy: long-wet record, start lma 0.118", -1)
make_ref("seasonal3b", 16, 12, "seasonal", "open start: seasonal record, start lma 0.32", 0)
for (h in history) if (!is.null(h)) cat(sprintf("%-12s %2d recordings, run %.0f s + sweeps %.0f s = %.1f min\n",
  h$run[1], nrow(h), sum(h$secs_run), sum(h$secs_sweep), sum(h$secs_run + h$secs_sweep) / 60))
