# score_rb.R [RESERVE]: Route B's real results (loopB_RESERVE.rds) against the truth: C1-C5 on
# the final, T = sum of runs + 2 x final (rows model), runs, each iterate's worst error and rows
# against E6 committed's, the first iterate at or under E6's worst error, the final scales and
# background nodes per region against E6's; route A's T beside it where scored.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/loop_run.R")
reserve <- if (length(commandArgs(TRUE))) as.numeric(commandArgs(TRUE)[1]) else 0.15
L <- readRDS(file.path(LO, sprintf("loopB_%.2f.rds", reserve))); rms <- function(x) sqrt(mean(x^2))
SA <- file.path(LO, sprintf("score_loop_%.2f.rds", reserve)); A <- if (file.exists(SA)) readRDS(SA)[[1]] else NULL
bg_nodes <- function(cs, S) { k <- node_class(cs, S); g <- c(F = "F", I1 = "I1", I2 = "I2", I3 = "I3", late = "L")[k]; t <- table(factor(g, RB_REG)); setNames(as.vector(t), RB_REG) }
rows <- list(); it <- list()
for (cs in names(L)) { z <- L[[cs]]; ref <- ref_of(cs); e6 <- e6_of(cs); ec6 <- (e6$qc - ref) / EPS; W6 <- max(abs(ec6))
  W <- vapply(z$q_runs, function(q) max(abs((q - ref) / EPS)), 0); R <- z$runs$rows
  err <- (z$q - ref) / EPS; cr <- crit(err, z$est)
  T <- sum(cost(R)) + 2 * cost(R[z$iter]); g6 <- (ec6 - (e6$qf - ref) / EPS) / (1 - e6$s); c6 <- all(abs(g6) < 1)
  T6 <- cost(e6$rc) + cost(e6$rf) + 2 * cost(if (c6) e6$rc else e6$rf)
  reach <- which(W <= W6)[1]
  nf <- bg_nodes(cs, rb_sched(cs, z$sv)); n6 <- bg_nodes(cs, e6$Sc)
  it[[cs]] <- data.frame(case = cs, iter = seq_along(W), W = W, W6 = W6, rows_e6 = R / e6$rc, z$runs[, RB_REG])
  rows[[cs]] <- data.frame(case = cs, set = if (cs %in% BANK) "bank" else "held", k = nrow(z$runs), final = z$iter, cap = z$cap,
    sv = paste(sprintf("%.2f", z$sv[RB_REG]), collapse = "/"), W = max(abs(err)), Wq = Q[which.max(abs(err))], rms = rms(err), W6 = W6,
    est = max(abs(z$est)), read = median((z$est / err)[abs(err) > 0.2]), pass = all(cr), fails = paste(names(cr)[!cr], collapse = ""),
    rows_e6 = R[z$iter] / e6$rc, T = T, T6 = T6, TA = if (!is.null(A) && cs %in% A$case) A$T[A$case == cs] else NA,
    reach_iter = reach, reach_rows = if (is.na(reach)) NA else R[reach] / e6$rc,
    nF = nf[["F"]], nF6 = n6[["F"]], nI1 = nf[["I1"]], nI16 = n6[["I1"]], nI2 = nf[["I2"]], nI26 = n6[["I2"]], nI3 = nf[["I3"]], nI36 = n6[["I3"]],
    map_hits = sum(!z$history$map_ok)) }
TB <- do.call(rbind, rows); rownames(TB) <- NULL; options(width = 260); print(TB, digits = 3)
cat("\niterates:\n"); print(do.call(rbind, it), digits = 3, row.names = FALSE)
for (st in c("bank", "held")) { X <- TB[TB$set == st, ]; if (!nrow(X)) next
  cat(sprintf("%s (%d): T %.0f against E6 %.0f (x%.3f)%s | pass %d | runs mean %.2f max %d | final rows / E6 c median %.2f (<= 1 on %d) | reaches E6's W on %d (median iterate %.1f, rows x%.2f) | s_F < s_I1 on %d | F and I1 nodes within 30%% of E6 on %d | map hits on %d\n",
    st, sum(X$T), sum(X$T6), sum(X$T) / sum(X$T6), if (all(!is.na(X$TA))) sprintf(", route A %.0f (x%.3f)", sum(X$TA), sum(X$T) / sum(X$TA)) else "",
    sum(X$pass), mean(X$k), max(X$k), median(X$rows_e6), sum(X$rows_e6 <= 1), sum(!is.na(X$reach_iter)), median(X$reach_iter, na.rm = TRUE), median(X$reach_rows, na.rm = TRUE),
    sum(as.numeric(sub("/.*", "", X$sv)) < as.numeric(sapply(strsplit(X$sv, "/"), `[`, 2))),
    sum(abs(X$nF / X$nF6 - 1) <= 0.3 & abs(X$nI1 / pmax(X$nI16, 1) - 1) <= 0.3), sum(X$map_hits > 0))) }
saveRDS(list(tab = TB, iter = do.call(rbind, it)), file.path(LO, sprintf("score_rb_%.2f.rds", reserve)))
