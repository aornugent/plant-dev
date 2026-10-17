# score_var.R [CASE]: V, cost at matched error. For each layout (N, M = opening node only,
# T = M with E6's inset from b = 17, C = opening inset fixed 12 d, and E6's committed/check
# pair) its rungs' rows, CPU, worst and rms error; then the rows at which the layout reaches
# E6 committed's worst and rms error, by interpolating log error against log rows between
# the rungs that bracket it.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/score_lib.R")
cs <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "dry"; ref <- ref5(cs)
row_of <- function(lay, s, x) { e <- err_of(x, ref); data.frame(layout = lay, s = s, n = length(x$node_times), rows = rows_of(x), cpu = cpu_of(x), worst = max(abs(e)), wq = names(e)[which.max(abs(e))], rms = r2(e), M = onM(e)) }
VR <- list(); for (L in c("N", "M", "T", "C")) for (k in c("20", "16", "10", "06")) { x <- h5_run(sprintf("h5_%s%s_%s", L, k, cs)); if (!is.null(x)) VR[[paste0(L, k)]] <- row_of(L, c("20" = 2, "16" = 1.6, "10" = 1, "06" = 0.625)[[k]], x) }
VR$E6c <- row_of("E6", 1, ag_run(sprintf("val_ins75_c_%s", cs))); VR$E6f <- row_of("E6", 1 / 1.6, ag_run(sprintf("val_ins75_f_%s", cs)))
VR <- do.call(rbind, VR); op <- options(width = 200); print(VR, digits = 3, row.names = FALSE)
at <- function(d, col, target) { d <- d[order(d$rows), ]; y <- log(d[[col]]); x <- log(d$rows)
  for (i in seq_len(nrow(d) - 1)) if ((y[i] - log(target)) * (y[i + 1] - log(target)) <= 0) return(exp(x[i] + (log(target) - y[i]) / (y[i + 1] - y[i]) * (x[i + 1] - x[i])))
  NA }
tw <- VR$worst[VR$layout == "E6" & VR$s == 1]; tr <- VR$rms[VR$layout == "E6" & VR$s == 1]; rw <- VR$rows[VR$layout == "E6" & VR$s == 1]
cat(sprintf("\nE6 committed: rows %.0f, worst %.2f, rms %.3f. Rows needed to match (ratio to E6 committed):\n", rw, tw, tr))
M <- do.call(rbind, lapply(unique(VR$layout), function(L) { d <- VR[VR$layout == L, ]; a <- at(d, "worst", tw); b <- at(d, "rms", tr)
  data.frame(layout = L, rows_at_worst = a, ratio_worst = a / rw, rows_at_rms = b, ratio_rms = b / rw) }))
print(M, digits = 3, row.names = FALSE)
saveRDS(list(R = VR, M = M), file.path(H5, sprintf("var_%s.rds", cs)))
