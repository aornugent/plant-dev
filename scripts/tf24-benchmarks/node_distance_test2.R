# Test 1b: disentangle the knot-spanning enrichment from the known
# "rejected steps are larger" fact. Within narrow step-size bands, does
# spanning a daily spline knot raise the rejection rate vs NOT spanning one
# at the SAME size? If yes -> knots have an effect independent of size.
# If the rejection rate is flat across span-count within a size band -> the
# earlier 1.5-1.8x enrichment was just the size confound.

raw <- "scripts/tf24-benchmarks/results/classifier_raw"
scen <- c("extended_drought", "dry_to_wet", "intense_storms",
          "long_horizon", "whiplash")
DK <- 1 / 365

knots_spanned <- function(t, h) {
  hi <- floor((t + h) * 365); lo <- ceiling(t * 365)
  pmax(0, hi - lo + 1)
}

for (nm in scen) {
  f <- file.path(raw, paste0(nm, ".rds")); if (!file.exists(f)) next
  d <- readRDS(f)$log
  d$nk <- knots_spanned(d$t, d$h)
  d$spans <- d$nk >= 1
  # size bands on the TRIAL h (log-spaced), so we compare like-sized attempts
  d <- d[d$h > 0, ]
  d$band <- cut(log10(d$h), breaks = 12)
  cat("\n===", nm, "  (rej rate by size band x spans-knot) ===\n")
  cat(sprintf("%-22s %6s | %7s %6s | %7s %6s | %6s\n",
      "h-band(log10 yr)", "n", "rej|no", "n_no", "rej|yes", "n_yes", "d(pp)"))
  for (b in levels(d$band)) {
    s <- d[d$band == b, ]; if (nrow(s) < 50) next
    no  <- s[!s$spans, ]; yes <- s[s$spans, ]
    if (nrow(no) < 20 || nrow(yes) < 20) next
    rno <- mean(no$ok == 0); ryes <- mean(yes$ok == 0)
    cat(sprintf("%-22s %6d | %6.1f%% %6d | %6.1f%% %6d | %+5.1f\n",
        b, nrow(s), 100*rno, nrow(no), 100*ryes, nrow(yes),
        100*(ryes - rno)))
  }
}
cat("\nInterpretation: d(pp) = (rej rate | spans knot) - (rej rate | no knot),",
    "\nin percentage points, WITHIN a size band. Consistently positive =>",
    "\nknots raise rejection independent of step size (stone-1 residual real).",
    "\n~0 or noisy => the whole-sample enrichment was the size confound.\n")
