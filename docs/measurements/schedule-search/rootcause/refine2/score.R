# score.R: each pass of each case's refinement against the reference ladder (which the loop
# never saw): true error, the loop's estimate and bound, coverage, false accepts, read, CPU.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/refine/s05"
R5 <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence/r5/runs"
cpu <- function(x) x$stand$cpu + (if (is.null(x$sweep_cpu)) 0 else x$sweep_cpu)
rows <- list()
for (cs in c("dry", "long-wet", "episodic-lma", "dry-flat", "epi-adG208")) {
  f <- file.path(OUT, cs, "fit.rds"); if (!file.exists(f)) next; fit <- readRDS(f); R <- ref_ladder(cs)
  for (i in seq_along(fit$history)) { h <- fit$history[[i]]; x <- readRDS(file.path(OUT, cs, sprintf("level%d.rds", h$level)))
    err <- (qv(x) - R$ref) / EPS; e <- h$estimate[Q]; unseen <- if (i == 1) 0.33 else 0.16; b <- abs(e) / 0.82 + unseen
    big <- abs(err) > 0.1; accept <- all(b < 1)
    rows[[length(rows) + 1]] <- data.frame(case = cs, pass = i, level = h$level, nodes = length(x$node_times),
      worst_err = max(abs(err)), worst_q = Q[which.max(abs(err))], worst_bound = max(b), accept = accept,
      false_accept = accept && max(abs(err)) > 1, covered = sum(abs(err) <= b), of = length(Q), min_margin = min(b - abs(err)),
      read = if (any(big)) median(e[big] / err[big]) else NA, read_lo = if (any(big)) min(e[big] / err[big]) else NA,
      cos = sum(e * err) / sqrt(sum(e^2) * sum(err^2)), worst_extrap = max(abs(err - e))) }
  co <- fit$costs; tot <- sum(co); g5 <- cpu(readRDS(file.path(R5, sprintf("G5_%s.rds", cs)))) + cpu(readRDS(file.path(R5, sprintf("G5o_%s.rds", cs))))
  cat(sprintf("%-13s %s, %d passes | CPU %.0f s (%s) | round 5 run + replay %.0f s, ratio %.2f\n", cs, fit$status, length(fit$history), tot,
    paste(sprintf("%s %.0f", rownames(co), rowSums(co)), collapse = ", "), g5, tot / g5)) }
tab <- do.call(rbind, rows); options(width = 250); print(format(tab, digits = 3), row.names = FALSE)
saveRDS(tab, file.path(OUT, "score.rds"))
