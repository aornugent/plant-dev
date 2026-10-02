# T1's tables, from t1_chain.R's per-attempt tables.
#   nice -n 10 Rscript DEV/rej_class/t1_report.R > DEV/rej_class/t1_report.txt
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
q3 <- function(x, p = c(.1, .5, .9)) paste(signif(quantile(x, p, na.rm = TRUE), 3), collapse = " / ")
share <- function(x) sprintf("%.1f%%", 100 * mean(x, na.rm = TRUE))
DAY <- 1 / 365
for (name in c("pics_3e-5", "pi_3e-5", "base_3e-5")) {
  x <- readRDS(file.path(O, paste0("t1_", name, ".rds")))
  # The rain change over the day after the knot on the interpolant, which passes
  # through rain[i + 1] at knot i / 365: 'change' (analyse.R's, from the daily
  # values either side) is the change over the day BEFORE the knot.
  rain <- readRDS(file.path(dirname(O), "pi", "runs", paste0(name, ".rds")))$rain
  ki <- round(x$knot / DAY)
  y_here <- rain[ki + 1]; y_next <- rain[ki + 2]
  x$change <- ifelse(y_here == 0 & y_next > 0, "starts", ifelse(y_here > 0 & y_next == 0, "stops",
                     ifelse(y_next > y_here, "rises", ifelse(y_next < y_here, "falls", "flat"))))
  first_day <- x$since > 0.001 & x$since <= 1
  S <- x$rej & x$cls == "other" & first_day
  B <- S & x$part == "soil"
  cat(sprintf("\n==== %s: 'other' rejections within a day after a knot %d, soil-bound %d (first tries %d)\n",
              name, sum(S), sum(B), sum(B & x$try == 1)))
  b <- x[B, ]
  rr <- b$chain / b$ratio
  cat("chain alone over coupled ratio, 10/50/90%:", q3(rr), "\n")
  cat("  within x2:", share(rr > 0.5 & rr < 2), " within x1.25:", share(rr > 0.8 & rr < 1.25),
      " chain alone > 1.1 (rejects too):", share(b$chain > 1.1), "\n")
  cat("  coupled ratio 10/50/90%:", q3(b$ratio), "| chain alone:", q3(b$chain), "\n")
  cat("  binding layer, coupled:", paste(tabulate(b$layer, 5), collapse = "/"),
      "| chain alone:", paste(tabulate(b$chain_layer, 5), collapse = "/"),
      "| agree:", share(b$layer == b$chain_layer), "\n")
  # The accepted step before: the one ending at this attempt's start.
  p <- x[b$prev, ]
  stopifnot(all(abs(p$t0 + p$h - b$t0) < 1e-12 | b$try > 1))
  cat("accepted step before: soil-bound", share(p$part == "soil"), "; its coupled ratio", q3(p$ratio),
      "; chain alone", q3(p$chain), "\n")
  ps <- p$part == "soil"
  cat("  chain alone over coupled on the step before (soil-bound ones):", q3(p$chain[ps] / p$ratio[ps]),
      "; within x2:", share(p$chain[ps] / p$ratio[ps] > 0.5 & p$chain[ps] / p$ratio[ps] < 2), "\n")
  cat("  jump, rejected over step before: coupled", q3(b$ratio / p$ratio), "| chain alone", q3(b$chain / p$chain),
      "| growth h/h_before", q3(b$h / p$h), "\n")
  cat("timing: since the knot, in delta, 10/50/90%:", q3(b$since), "| accepted steps since the knot:\n")
  print(table(pmin(b$n_since, 6)))
  cat("rain change over the day after the knot, on the interpolant:\n"); print(table(b$change))
  cat("rejected share of first tries within the day, by change (all first tries there):\n")
  f <- first_day & x$try == 1
  print(round(tapply(x$rej[f] & x$cls[f] == "other" & x$part[f] == "soil", x$change[f], mean), 3))
  cat("by change, chain alone within x2 / chain alone > 1.1:\n")
  print(rbind(within2 = round(tapply(rr > 0.5 & rr < 2, b$change, mean), 3),
              chain_rejects = round(tapply(b$chain > 1.1, b$change, mean), 3),
              n = tapply(rr, b$change, length)))
  cat("by step since the knot, chain alone within x2 / > 1.1:\n")
  print(rbind(within2 = round(tapply(rr > 0.5 & rr < 2, pmin(b$n_since, 6), mean), 3),
              chain_rejects = round(tapply(b$chain > 1.1, pmin(b$n_since, 6), mean), 3),
              n = tapply(rr, pmin(b$n_since, 6), length)))
  # Base rates: every soil-bound attempt within the day, accepted ones too.
  A <- first_day & x$part == "soil" & !is.na(x$ratio)
  ra <- x$chain[A] / x$ratio[A]
  cat(sprintf("all soil-bound attempts within the day (%d): chain alone over coupled %s; within x2 %s\n",
              sum(A), q3(ra), share(ra > 0.5 & ra < 2)))
  ac <- A & !x$rej
  cat(sprintf("  of them accepted (%d): within x2 %s; chain alone > 1.1 on %s\n", sum(ac),
              share(x$chain[ac] / x$ratio[ac] > 0.5 & x$chain[ac] / x$ratio[ac] < 2), share(x$chain[ac] > 1.1)))
  far <- x$since > 10 & x$part == "soil" & !is.na(x$ratio)
  cat(sprintf("soil-bound attempts over 10 days after a knot (%d): chain alone over coupled %s\n",
              sum(far), q3(x$chain[far] / x$ratio[far])))
  # The other classes' rejections, soil-bound, for comparison.
  for (cl in c("knot", "overshoot", "stability")) {
    z <- x$rej & x$cls == cl & x$part == "soil"
    if (sum(z)) cat(sprintf("  %s, soil-bound rejected (%d): chain alone over coupled %s, within x2 %s\n",
                            cl, sum(z), q3(x$chain[z] / x$ratio[z]), share(x$chain[z] / x$ratio[z] > 0.5 & x$chain[z] / x$ratio[z] < 2)))
  }
}
