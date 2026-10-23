# Does the live P reproduce through plant's Individual at the logged inputs, and
# how much of P is lost when the five soil layers are replaced by one number?
# Candidates: psi_w, the wet-conductance-weighted mean, and two numbers (layer 1
# and the weighted mean of the rest).
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table/common.R")
d <- readRDS(file.path(TMP, "inputs.rds"))
d <- d[d$who == "resident traits", ]
set.seed(2)
# Spread the sample over the soil's dryness: half uniform, half from drier calls.
dry <- which(d$psi1 > 0.2)
i <- c(sample(nrow(d), 1500), sample(dry, 1500))
x <- d[i, ]
f <- leaf_eval_factory()
ev <- function(light, psi, h) f(light, psi, h)[["P"]]

x$P_re <- mapply(function(k) ev(x$light[k], unlist(x[k, paste0("psi", 1:5)]), x$height[k]),
                 seq_len(nrow(x)))
x$P_w <- mapply(function(k) ev(x$light[k], rep(x$psi_w[k], 5), x$height[k]), seq_len(nrow(x)))
x$P_1 <- mapply(function(k) ev(x$light[k], rep(x$psi1[k], 5), x$height[k]), seq_len(nrow(x)))
x$P_2 <- mapply(function(k) {
  w <- root_weights(x$height[k])
  psi <- unlist(x[k, paste0("psi", 1:5)])
  deep <- if (sum(w[-1]) > 0) sum(w[-1] * psi[-1]) / sum(w[-1]) else psi[1]
  ev(x$light[k], c(psi[1], rep(deep, 4)), x$height[k])
}, seq_len(nrow(x)))
saveRDS(x, file.path(TMP, "compress.rds"))

scale <- median(abs(d$P))
err <- function(e) c(rms = sqrt(mean(e^2)), p99 = unname(quantile(abs(e), 0.99)),
                     max = max(abs(e)))
cat("P scale (median |P|):", scale, "\n")
for (nm in c("P_re", "P_w", "P_1", "P_2")) {
  cat(sprintf("%-5s all: %s | psi1>0.2: %s\n", nm,
              paste(signif(err(x[[nm]] - x$P), 3), collapse = " "),
              paste(signif(err((x[[nm]] - x$P)[x$psi1 > 0.2]), 3), collapse = " ")))
}
