# score_k1.R DIR: the corrected answer (run − estimate) of each fit in DIR against the reference
# ladders: its true error, the bound 0.5|e| + u, coverage; the run's own error beside it.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
O <- commandArgs(TRUE)[1]
for (f in sort(list.files(O, "\\.rds$", full.names = TRUE))) {
  nm <- sub("\\.rds$", "", basename(f)); cs <- sub("_s[0-9.]+$", "", nm); fit <- readRDS(f)
  if (fit$status == "failed") { cat(nm, "failed:", fit$error, "\n"); next }
  R <- ref_ladder(cs); k <- intersect(names(fit$answer), Q)
  err <- (fit$answer[k] - R$ref[k]) / EPS[k]; run <- (fit$run[k] - R$ref[k]) / EPS[k]; b <- fit$bound[k]
  cat(sprintf("%-20s %s at level %d, %d nodes | corrected: worst %.3f (%s), covered %d/%d, min margin %.3f, worst bound %.2f | run: worst %.3f | CPU %.0f s\n",
    nm, fit$status, fit$level, length(nodes_of(fit$schedule, fit$level)), max(abs(err)), k[which.max(abs(err))], sum(abs(err) <= b), length(k),
    min(b - abs(err)), max(b), max(abs(run)), sum(fit$costs))) }
