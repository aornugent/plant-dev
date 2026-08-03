# Part 2: is the refinement criterion equally stringent in the two coordinates?
#
# Evaluate BOTH error metrics on the SAME physical population state.  For a
# snapshot the competition integrand in the two conventions is related by the
# flux identity n_h * g = n_t, so y_h = y_t / g and y_t = y_h * g, while the
# abscissa is -height or introduction time.  Both quadratures approximate the
# same total leaf area L, so both metrics are dimensionless relative errors and
# the ratio E_h / E_t is the criterion's coordinate mis-scaling, measured
# node-by-node with no confounding from the run itself.
source("/home/user/plant-dev/probes/40-lib.R")
a <- commandArgs(TRUE); model <- a[1]

metrics_at <- function(patch, tag, bd) {
  sp <- patch$species[[1]]
  n <- sp$size
  if (n < 5) return(NULL)
  env <- patch$environment
  h <- sp$heights; tt <- sp$node_times
  y_own <- sp$compute_competition_effect_by_nodes
  g <- numeric(n)
  for (i in seq_len(n)) {
    ind <- sp$node_at(i)$individual; ind$compute_rates(env)
    g[i] <- ind$rate("height")
  }
  # total competition effect at ground level, the metric's normaliser
  L <- patch$compute_competition(0)
  # the two integrands, in the two density conventions
  y_t <- if (bd) y_own else y_own * g
  y_h <- if (bd) y_own / g else y_own
  E_t <- plant:::local_error_integration(tt, y_t, L)
  E_h <- plant:::local_error_integration(-h, y_h, L)
  data.frame(tag = tag, time = patch$time, bd = bd, node = seq_len(n),
             t = tt, h = h, g = g, y_own = y_own, L = L,
             E_t = E_t, E_h = E_h,
             dt = c(NA, diff(tt)), dh = c(NA, -diff(h)))
}

res <- list()
for (bd in c(FALSE, TRUE)) {
  scm <- make_scm(model, bd)
  scm$collect <- TRUE
  t0 <- Sys.time(); scm$run()
  cat(sprintf("%s %s: %d snapshots, %.1fs\n", model, if (bd) "bd" else "ht",
              length(scm$history), as.numeric(difftime(Sys.time(), t0, units="secs"))))
  flush.console()
  H <- scm$history
  idx <- unique(round(seq(10, length(H), length.out = 12)))
  for (i in idx) {
    r <- tryCatch(metrics_at(H[[i]], if (bd) "bd" else "ht", bd),
                  error = function(e) { cat("  snap", i, "err:", conditionMessage(e), "\n"); NULL })
    if (!is.null(r)) res[[length(res) + 1]] <- r
  }
  saveRDS(do.call(rbind, res), sprintf("/home/user/plant-dev/probes/out/46-scale-%s.rds", model))
}
cat("DONE\n")
