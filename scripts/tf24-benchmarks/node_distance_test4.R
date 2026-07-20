# Test 1d: size the lever. Test 3 confirmed a real, size-independent knot
# effect. How much of the total rejection fraction is ATTRIBUTABLE to knot
# crossing? Counterfactual: within fine log-h bins, if knot-spanning attempts
# rejected at the same rate as matched-size non-spanning attempts, what would
# the overall reject fraction be? The gap is the CEILING on what any
# knot-avoidance scheme could save (ignoring the cost of shortened steps and
# the fact that flat dry-spell knots are harmless -> so the real win is less).

raw <- "scripts/tf24-benchmarks/results/classifier_raw"
scen <- c("extended_drought", "dry_to_wet", "intense_storms",
          "long_horizon", "whiplash")
DK <- 1 / 365
knots_spanned <- function(t, h) {
  hi <- floor((t + h) * 365); lo <- ceiling(t * 365); pmax(0, hi - lo + 1) }

cat(sprintf("%-18s %8s %10s %12s %10s\n",
    "scenario", "rej%", "cf_rej%", "attrib(pp)", "span&chg%"))
for (nm in scen) {
  f <- file.path(raw, paste0(nm, ".rds")); if (!file.exists(f)) next
  b <- readRDS(file.path("scripts/tf24-benchmarks/data", paste0(nm, ".rds")))
  d <- readRDS(f)$log; d <- d[d$h > 0, ]
  d$spans <- knots_spanned(d$t, d$h) >= 1
  # fine size bins (0.1 decade)
  d$bin <- cut(log10(d$h), breaks = seq(-6, 1, by = 0.1))
  # counterfactual reject: knot-spanning attempts inherit the matched-bin
  # non-spanning reject rate
  cf <- d$ok
  for (bb in levels(d$bin)) {
    idx <- which(d$bin == bb)
    if (!length(idx)) next
    no <- d[idx, ]; base <- no[!no$spans, ]
    if (nrow(base) < 20) next
    rbase <- mean(base$ok == 0)          # non-spanning reject rate in bin
    sp <- idx[d$spans[idx]]
    if (!length(sp)) next
    # expected accepts if spanning rejected at baseline rate
    cf[sp] <- 1 - rbase                  # fractional "accept prob"
  }
  rej   <- mean(d$ok == 0)
  cf_rej <- 1 - mean(ifelse(d$spans, cf, d$ok))  # blend: spanning uses cf prob
  # fraction of attempts that span a knot whose value is actually CHANGING
  # (flat dry-spell knots have no 3rd-deriv jump -> harmless). Approx: a knot
  # is "changing" if the daily rain differs across it.
  chg_knots <- which(diff(b$rain) != 0)          # indices k where rain changes
  chg_times <- chg_knots / 365
  near_chg <- sapply(which(d$spans), function(i) {
    any(abs(chg_times - d$t[i]) < d$h[i] + DK) })
  span_and_chg <- length(near_chg) > 0 && sum(near_chg) > 0
  frac_span_chg <- if (nrow(d)) sum(d$spans) / nrow(d) *
      (if (length(near_chg)) mean(near_chg) else 0) else 0
  cat(sprintf("%-18s %7.1f%% %9.1f%% %11.1f %9.1f%%\n",
      nm, 100*rej, 100*cf_rej, 100*(rej - cf_rej), 100*frac_span_chg))
}
cat("\ncf_rej% = reject fraction if knot-spanning steps rejected at the",
    "matched-size\n  non-spanning rate. attrib(pp) = rej - cf = ceiling on",
    "knot-attributable\n  rejections. span&chg% = frac of ALL attempts that",
    "span a knot near a\n  value CHANGE (the harmful knots; flat dry-spell",
    "knots excluded).\n")
