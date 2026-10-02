# The first-day soil-bound 'other' rejections the chain alone does not reproduce
# within x2, and the rain each attempt sees on the interpolant.
#   nice -n 10 Rscript DEV/rej_class/t1_residue.R
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
q3 <- function(x, p = c(.1, .5, .9)) paste(signif(quantile(x, p, na.rm = TRUE), 3), collapse = " / ")
for (name in c("pics_3e-5", "pi_3e-5", "base_3e-5")) {
  x <- readRDS(file.path(O, paste0("t1_", name, ".rds")))
  B <- x$rej & x$cls == "other" & x$since > 0.001 & x$since <= 1 & x$part == "soil"
  b <- x[B, ]
  rr <- b$chain / b$ratio
  cat(sprintf("\n== %s: %d; chain alone over coupled < 0.5: %d, > 2: %d\n", name, nrow(b), sum(rr <= 0.5), sum(rr >= 2)))
  mis <- b[rr <= 0.5 | rr >= 2, c("t0", "h", "since", "n_since", "change", "ratio", "chain", "layer", "chain_layer",
                                  "theta1", "theta2", "theta3", "rain_t0", "rain_t1", "crossed")]
  mis$h <- mis$h * 365
  print(head(mis[order(mis$t0), ], 40), digits = 3, row.names = FALSE)
  cat("in 'rises', chain alone over coupled:", q3(rr[b$change == "rises"]), "\n")
  # The rain on the interpolant across the attempt: rising or falling there.
  cat("rain across the attempt (interpolant), rising / falling / flat zero / starting / stopping:\n")
  trend <- ifelse(b$rain_t0 == 0 & b$rain_t1 == 0, "zero", ifelse(b$rain_t0 == 0, "starting",
             ifelse(b$rain_t1 == 0, "stopping", ifelse(b$rain_t1 > b$rain_t0, "rising", "falling"))))
  print(table(trend, b$change))
}
