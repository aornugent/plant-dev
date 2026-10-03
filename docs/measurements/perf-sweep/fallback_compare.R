# Step recordings whose tape is far above what their node count predicts: where
# the light field's prefix form broke and every knot walked every node. Each
# sweep-tape recording is matched to the row it transposes (descent order).
#   Rscript fallback_compare.R out/t3e5_u108_guard out/t3e5_u108_spread
# Each argument is a stem, or stem=reference_stem to take the regular size from
# the reference run (one whose field never left its prefix form).
regular_fit <- function(st) {
  lo <- aggregate(statements ~ nodes, data = st, FUN = function(v) quantile(v, 0.25))
  lm(statements ~ nodes, data = lo)
}
load_steps <- function(stem) {
  d <- read.delim(paste0(stem, ".tsv"))
  r <- d[d$kind == "rec", ]
  tp <- as.integer(names(which.max(table(r$tape))))
  r <- r[r$tape == tp, ]
  r$nodes <- (r$inputs - 60) / 9
  m <- ave(r$statements, r$inputs, FUN = max)
  r[r$nodes > 0 & r$statements >= 0.4 * m, ]
}
for (arg in commandArgs(TRUE)) {
  parts <- strsplit(arg, "=", fixed = TRUE)[[1]]
  stem <- parts[1]
  ref <- if (length(parts) > 1) regular_fit(load_steps(parts[2])) else NULL
  d <- read.delim(paste0(stem, ".tsv"))
  r <- d[d$kind == "rec", ]
  tp <- as.integer(names(which.max(table(r$tape))))
  r <- r[r$tape == tp, ]
  x <- readRDS(paste0(stem, ".rds"))
  rows <- x$rec_rows
  n <- nrow(rows)
  k <- n - seq_len(nrow(r)) + 1
  r$time <- rows$time[k - 1]
  r$nodes <- (r$inputs - 60) / 9
  m <- ave(r$statements, r$inputs, FUN = max)
  st <- r[r$nodes > 0 & r$statements >= 0.4 * m, ]
  # The regular size: a robust line through the lower half at each node count.
  fit <- if (is.null(ref)) regular_fit(st) else ref
  st$pred <- predict(fit, newdata = st)
  st$excess <- st$statements / st$pred
  fb <- st$excess > 1.3
  rec_fit <- lm(rec_s ~ nodes, data = st[!fb, ])
  cat(sprintf("== %s: sweep %.1f s cpu (recorded forward %.1f s); %d step recordings, %.0f rows\n",
              stem, x$sweep$cpu[["user"]], x$recorded$cpu[["user"]], nrow(st), sum(st$nodes)))
  cat(sprintf("   regular tape: %.0f + %.0f statements per node per step\n", coef(fit)[1], coef(fit)[2]))
  cat(sprintf("   recordings > 1.3x regular: %d (%.2f%% of steps, %.2f%% of rows); their tape %.2fx regular; their recording time %.1f s of %.1f s step recording (%.1f s if regular); reverse %.1f s of %.1f s\n",
              sum(fb), 100 * mean(fb), 100 * sum(st$nodes[fb]) / sum(st$nodes),
              if (any(fb)) sum(st$statements[fb]) / sum(st$pred[fb]) else NA,
              sum(st$rec_s[fb]), sum(st$rec_s), sum(predict(rec_fit, newdata = st[fb, ])),
              sum(st$sweep_s[fb]), sum(st$sweep_s)))
  cat(sprintf("   largest step tape %.1f MB (regular at that width %.1f MB)\n",
              max(st$bytes) / 2^20, max(st$bytes[!fb]) / 2^20))
  if (any(fb)) {
    yr <- cut(st$time, seq(0, 40, by = 2), right = FALSE)
    tab <- data.frame(window = levels(yr), steps = as.vector(table(yr)),
                      fallback_pct = round(100 * tapply(fb, yr, mean), 1),
                      excess = round(tapply(st$excess, yr, function(v) max(v)), 2))
    print(tab[tab$steps > 0, ], row.names = FALSE)
  }
  saveRDS(st, paste0(stem, "_fallback.rds"))
}
