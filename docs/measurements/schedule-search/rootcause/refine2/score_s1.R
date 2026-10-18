# score_s1.R: the canonical runs (scale 1, in memory) against the reference ladders: each pass's
# true error, the loop's estimate and bound, coverage, read, and CPU against round 5's.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/refine/s1"
R5 <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence/r5/runs"
cpu5 <- function(n) { x <- readRDS(file.path(R5, n)); x$stand$cpu + x$sweep_cpu }
rows <- list()
for (cs in c("dry", "long-wet", "episodic-lma", "dry-flat", "epi-adG208")) {
  f <- file.path(O, paste0(cs, ".rds")); if (!file.exists(f)) next; fit <- readRDS(f); R <- ref_ladder(cs)
  if (fit$status == "failed") { cat(cs, "failed:", fit$error, "\n"); next }
  for (i in seq_along(fit$history)) { h <- fit$history[[i]]; k <- intersect(names(h$answer), Q)
    err <- (h$answer[k] - R$ref[k]) / EPS[k]; e <- h$estimate[k]; b <- abs(e) / 0.82 + if (i == 1) 0.33 else 0.19
    big <- abs(err) > 0.2
    rows[[length(rows) + 1]] <- data.frame(case = cs, pass = i, level = h$level, nodes = h$nodes, n_q = length(k),
      worst_err = max(abs(err)), worst_q = k[which.max(abs(err))], worst_bound = max(b), accept = all(b < 1),
      covered = sum(abs(err) <= b), min_margin = min(b - abs(err)), read = if (any(big)) median(e[big] / err[big]) else NA,
      read_lo = if (any(big)) min(e[big] / err[big]) else NA, worst_extrap = max(abs(err - e))) }
  tot <- sum(fit$costs); g5 <- cpu5(sprintf("G5_%s.rds", cs)) + cpu5(sprintf("G5o_%s.rds", cs))
  cat(sprintf("%-13s %s | CPU %.0f s (%s) | round 5 run + replay %.0f s, ratio %.2f\n", cs, fit$status, tot,
    paste(sprintf("%s %.0f", rownames(fit$costs), rowSums(fit$costs)), collapse = ", "), g5, tot / g5)) }
tab <- do.call(rbind, rows); options(width = 250); print(format(tab, digits = 3), row.names = FALSE)
