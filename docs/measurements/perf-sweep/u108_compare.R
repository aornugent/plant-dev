# The u108 sweeps of both builds, recording by recording: each sweep-tape
# recording is matched to the row it transposes (the descent visits rows last
# to first), so its size and time can be read against the state the step starts
# from -- its node count, and whether the field's prefix form held there.
#   Rscript u108_compare.R out/u108_guard out/u108_spread
args <- commandArgs(TRUE)
load_run <- function(stem) {
  d <- read.delim(paste0(stem, ".tsv"))
  r <- d[d$kind == "rec", ]
  tp <- as.integer(names(which.max(table(r$tape))))
  r <- r[r$tape == tp, ]
  x <- readRDS(paste0(stem, ".rds"))$reps[[1]]
  rows <- x$rec_rows
  n <- nrow(rows)
  # Recording i transposes row n - i + 1 (1-based), which starts from row n - i.
  k <- n - seq_len(nrow(r)) + 1
  stopifnot(length(k) == n - 1)
  from <- rows[k - 1, ]
  r$time <- from$time
  r$nodes <- (r$inputs - 50 - 10) / 9
  stopifnot(all(abs(r$nodes - from$nodes) < 1e-9 | is.na(from$nodes)))
  r$insertion <- rows$insertion[k] | (r$statements < 0.4 * ave(r$statements, r$inputs, FUN = max))
  r$ordered <- from$decreasing & from$newborn_below
  r$decreasing <- from$decreasing
  list(r = r, x = x, stem = stem)
}
runs <- lapply(args, load_run)
for (run in runs) {
  r <- run$r; x <- run$x
  st <- r[!r$insertion & r$nodes > 0, ]
  cat(sprintf("== %s: plain forward %.1f s, recorded %.1f s, sweep %.1f s (sweep/plain %.2f); rows %.0f; %d step and %d insertion recordings\n",
              run$stem, x$plain$cpu[["user"]], x$recorded$cpu[["user"]], x$sweep$cpu[["user"]],
              x$sweep$cpu[["user"]] / x$plain$cpu[["user"]], x$recorded$rows,
              nrow(st), sum(r$insertion)))
  cat(sprintf("   step recordings: %.0f statements per row; prefix form broken at %.2f%% of step starts (heights out of order %.2f%%)\n",
              sum(st$statements) / sum(st$nodes), 100 * mean(!st$ordered, na.rm = TRUE),
              100 * mean(!st$decreasing, na.rm = TRUE)))
  fit <- lm(statements ~ nodes, data = st[st$ordered %in% TRUE, ])
  cat(sprintf("   where it holds: %.0f + %.0f per node statements per step\n", coef(fit)[1], coef(fit)[2]))
  if (any(!st$ordered, na.rm = TRUE)) {
    b <- st[st$ordered %in% FALSE, ]
    pred <- predict(fit, newdata = b)
    cat(sprintf("   where it breaks: %d steps, statements %.2fx the fit, recording time %.2fx (%.1f s of %.1f s step recording)\n",
                nrow(b), sum(b$statements) / sum(pred),
                sum(b$rec_s) / sum(predict(lm(rec_s ~ nodes, data = st[st$ordered %in% TRUE, ]), newdata = b)),
                sum(b$rec_s), sum(st$rec_s)))
  }
  yr <- cut(st$time, c(0, 5, 8, 11, 19, 23, 32, 35, 40), right = FALSE)
  tab <- data.frame(
    years = levels(yr),
    steps = as.vector(table(yr)),
    broken_pct = round(100 * tapply(!st$ordered, yr, mean, na.rm = TRUE), 2),
    stmts_per_row = round(tapply(st$statements, yr, sum) / tapply(st$nodes, yr, sum)),
    rec_us_per_row = round(1e6 * tapply(st$rec_s, yr, sum) / tapply(st$nodes, yr, sum), 1))
  print(tab, row.names = FALSE)
  run$tab <- tab
  saveRDS(list(r = r, tab = tab), paste0(run$stem, "_aligned.rds"))
}
