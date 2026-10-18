# fr_score_ns.R: the frontier's libNS runs (fr_run.sh) against the references: plain (K0) and
# corrected (K1, Q - e) answers per configuration, bounds, coverage, read, rows and CPU; the
# tolerance pair on episodic-lma; and the coordinator's libNS canonical fits, where present.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
O <- file.path(SP, "frontier/ns"); NSF <- file.path(SP, "refine/ns")
U <- 0.33; BETA <- 0.5
score <- function(cs, err, e, extra = list()) { k <- abs(err) > 0.2; bp <- abs(e) / 0.82 + U; ec <- err - e; bc <- BETA * abs(e) + U
  data.frame(case = cs, extra, worst = max(abs(err)), q = names(err)[which.max(abs(err))], rms = sqrt(mean(err^2)),
    bound = max(bp), accept = all(bp < 1), cover = sum(abs(err) <= bp), read = if (any(k)) median(e[k] / err[k]) else NA,
    read_lo = if (any(k)) min(e[k] / err[k]) else NA, c_worst = max(abs(ec)), c_q = names(ec)[which.max(abs(ec))], c_rms = sqrt(mean(ec^2)),
    c_bound = max(bc), c_accept = all(bc < 1), c_cover = sum(abs(ec) <= bc), c_resid_over_u = max(abs(ec) - U), check.names = FALSE) }
rows <- list(); runs <- list()
for (f in list.files(O, "_s[0-9.]+_t.*\\.rds$", full.names = TRUE)) { x <- readRDS(f); cs <- x$case
  if (!is.null(x$failed) || is.null(x[["replay"]]) || is.character(x$run$q) || is.character(x[["replay"]]$q)) { cat(basename(f), "failed:", x$failed, x$replay_failed, "\n"); next }
  R <- ref_ladder(cs); q <- x$run$q[Q]; err <- (q - R$ref[Q]) / EPS; e <- (x[["replay"]]$q[Q] - q) / 3 / EPS
  runs[[basename(f)]] <- list(case = cs, scale = x$scale, tol = x$tol, q = q, err = err, e = e)
  rows[[basename(f)]] <- score(cs, err, e, list(scale = x$scale, tol = x$tol, nodes = x$run$nodes, rows = x$run$rows, steps = x$run$steps,
    cpu_run = sum(x$run$cpu), cpu_rep = sum(x[["replay"]]$cpu), rep_share = sum(x[["replay"]]$cpu) / sum(x$run$cpu), ref_own = max(abs(R$own)))) }
options(width = 250)
if (length(rows)) { tab <- do.call(rbind, rows); print(format(tab, digits = 3), row.names = FALSE); saveRDS(list(tab = tab, runs = runs), file.path(O, "score.rds")) }

# Scale 0.7 against scale 1 per case: rows, CPU (same process, in sequence) and error growth.
for (cs in unique(vapply(runs, `[[`, "", "case"))) { a <- runs[[sprintf("%s_s1_t0.0001.rds", cs)]]; b <- runs[[sprintf("%s_s0.7_t0.0001.rds", cs)]]
  if (is.null(a) || is.null(b)) next; ra <- rows[[sprintf("%s_s1_t0.0001.rds", cs)]]; rb <- rows[[sprintf("%s_s0.7_t0.0001.rds", cs)]]
  cat(sprintf("%s: s0.7/s1 rows %.3f, CPU run+replay %.3f, worst plain %.2f -> %.2f (x%.2f), corrected %.2f -> %.2f\n", cs, rb$rows / ra$rows,
    (rb$cpu_run + rb$cpu_rep) / (ra$cpu_run + ra$cpu_rep), ra$worst, rb$worst, rb$worst / ra$worst, ra$c_worst, rb$c_worst)) }

# The tolerance pair: same schedule at 1e-4 and 3e-4.
a <- runs[["episodic-lma_s1_t0.0001.rds"]]; b <- runs[["episodic-lma_s1_t0.0003.rds"]]
if (!is.null(a) && !is.null(b)) { ra <- rows[["episodic-lma_s1_t0.0001.rds"]]; rb <- rows[["episodic-lma_s1_t0.0003.rds"]]; mv <- b$err - a$err
  cat(sprintf("episodic-lma 3e-4 vs 1e-4: rows %.3f, steps %.3f, CPU run+replay %.3f; move max %.3f (%s) rms %.3f; estimate change rms %.3f max %.3f\n",
    rb$rows / ra$rows, rb$steps / ra$steps, (rb$cpu_run + rb$cpu_rep) / (ra$cpu_run + ra$cpu_rep), max(abs(mv)), names(mv)[which.max(abs(mv))],
    sqrt(mean(mv^2)), sqrt(mean((b$e - a$e)^2)), max(abs(b$e - a$e)))) }

# The coordinator's libNS canonical fits (pass 1), plain and corrected.
if (dir.exists(NSF)) { ft <- list()
  for (f in list.files(NSF, "\\.rds$", full.names = TRUE)) { fit <- tryCatch(readRDS(f), error = function(e) NULL)
    if (is.null(fit$history) || !length(fit$history)) next; cs <- sub("\\.rds$", "", basename(f)); h <- fit$history[[1]]; k <- intersect(Q, names(h$answer))
    R <- ref_ladder(cs); err <- (h$answer[k] - R$ref[k]) / EPS[k]
    ft[[cs]] <- score(cs, err, h$estimate[k], list(status = fit$status, passes = length(fit$history), nodes = h$nodes, cpu = sum(fit$costs))) }
  if (length(ft)) { cat("\nCoordinator's libNS canonical fits, pass 1:\n"); print(format(do.call(rbind, ft), digits = 3), row.names = FALSE) } }

# Runs without a replay (fr_run2.sh): each one's error, and its move from the same schedule at 1e-4.
for (f in list.files(O, "_s[0-9.]+_t.*\\.rds$", full.names = TRUE)) { x <- readRDS(f); if (!is.null(x[["replay"]]) || is.null(x$run) || is.character(x$run$q)) next
  cs <- x$case; R <- ref_ladder(cs); err <- (x$run$q[Q] - R$ref[Q]) / EPS; b <- runs[[sprintf("%s_s%g_t%g.rds", cs, x$scale, 1e-4)]]
  mv <- if (is.null(b)) NA * err else err - b$err; o <- order(-abs(mv))[1:5]
  cat(sprintf("\n%s s%g at %g (no replay): worst %.2f (%s), TF24_cost_scale %.2f, rms %.3f; rows %.0f, steps %d, CPU %.0f s\n  move from 1e-4: max %.3f rms %.3f; largest %s\n",
    cs, x$scale, x$tol, max(abs(err)), names(err)[which.max(abs(err))], err[["TF24_cost_scale"]], sqrt(mean(err^2)), x$run$rows, x$run$steps, sum(x$run$cpu),
    max(abs(mv)), sqrt(mean(mv^2)), paste(sprintf("%s %+.2f", names(mv)[o], mv[o]), collapse = ", "))) }
