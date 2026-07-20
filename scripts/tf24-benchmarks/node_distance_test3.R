# Test 1c: settle the top-band ambiguity. Use NARROW size windows (0.1 decade)
# in the region h ~ 0.3-1.0 x DK, where spanning-a-knot and NOT-spanning both
# occur at essentially the same step size (a sub-knot step either straddles a
# knot or fits between, depending only on phase, not size). If spanning still
# raises rejection here at fixed size -> real knot effect. If it collapses to
# ~0 -> the top-band jump in test 1b was the residual size confound.

raw <- "scripts/tf24-benchmarks/results/classifier_raw"
scen <- c("extended_drought", "dry_to_wet", "intense_storms",
          "long_horizon", "whiplash")
DK <- 1 / 365

knots_spanned <- function(t, h) {
  hi <- floor((t + h) * 365); lo <- ceiling(t * 365)
  pmax(0, hi - lo + 1)
}

# narrow windows as fractions of DK
wins <- list(c(0.3, 0.45), c(0.45, 0.6), c(0.6, 0.8), c(0.8, 1.0))

for (nm in scen) {
  f <- file.path(raw, paste0(nm, ".rds")); if (!file.exists(f)) next
  d <- readRDS(f)$log; d <- d[d$h > 0, ]
  d$spans <- knots_spanned(d$t, d$h) >= 1
  cat("\n===", nm, "===\n")
  cat(sprintf("%-14s %6s | %7s %6s | %7s %6s | %6s\n",
      "h/DK window", "n", "rej|no", "n_no", "rej|yes", "n_yes", "d(pp)"))
  for (w in wins) {
    s <- d[d$h >= w[1]*DK & d$h < w[2]*DK, ]
    no <- s[!s$spans, ]; yes <- s[s$spans, ]
    if (nrow(no) < 30 || nrow(yes) < 30) next
    rno <- mean(no$ok == 0); ryes <- mean(yes$ok == 0)
    cat(sprintf("[%.2f,%.2f]DK  %6d | %6.1f%% %6d | %6.1f%% %6d | %+5.1f\n",
        w[1], w[2], nrow(s), 100*rno, nrow(no), 100*ryes, nrow(yes),
        100*(ryes - rno)))
  }
}
cat("\nHere step size is held to a 0.15-0.2x-DK-wide window, so span/no-span",
    "\ndiffer by PHASE not size. Persistent +d(pp) => real knot effect;",
    "\ncollapse to ~0 => test 1b's top-band jump was the size confound.\n")
