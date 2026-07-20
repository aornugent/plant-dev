# Test 1 (fresh-Oracle stone 1, corrected): does step rejection / small-step
# behaviour co-locate with the forcing SPLINE KNOTS (the daily grid k/365),
# as opposed to the sparse value-change FEATURES the classifier already looked
# at?
#
# Context: the driver is a C2 cubic spline through daily knots (spacing
# 1/365 = 2.74e-3 yr). A cubic spline has a JUMPING 3rd derivative at every
# knot, so an order-5 method cannot reach full order across a knot. No prior
# instrument logged distance-to-knot (only value-change features). This reads
# the saved per-attempt step log (t, h, ok) offline -- free, no re-run.
#
# Two questions:
#  Q1 (density): are the daily knots DENSER than the steps? If steps span many
#      knots, co-location is not even a meaningful discriminator (every step
#      crosses knots) -- but that itself would mean the knot non-smoothness is
#      crossed on essentially every step => a global/broadband order cap.
#  Q2 (enrichment): among steps small enough to sit between knots, are rejects
#      / small steps enriched for knot proximity vs accepted steps?

raw <- "scripts/tf24-benchmarks/results/classifier_raw"
scen <- c("extended_drought", "dry_to_wet", "intense_storms",
          "long_horizon", "whiplash")
DK <- 1 / 365  # knot spacing (yr)

nearest_knot_dist <- function(t) {
  frac <- t * 365
  pmin(frac - floor(frac), ceiling(frac) - frac) / 365
}
knots_spanned <- function(t, h) {
  # number of daily knots strictly inside (t, t+h]
  hi <- floor((t + h) * 365)
  lo <- ceiling(t * 365)
  pmax(0, hi - lo + 1)
}

cat(sprintf("%-18s %7s %6s %8s %8s %8s %8s %8s %8s\n",
    "scenario", "nAtt", "rej%", "medH/DK", "p10H/DK",
    "spanAcc", "spanRej", "subK_acc", "subK_rej"))

allrows <- list()
for (nm in scen) {
  f <- file.path(raw, paste0(nm, ".rds"))
  if (!file.exists(f)) next
  d <- readRDS(f)$log
  d$hDK   <- d$h / DK
  d$nk    <- knots_spanned(d$t, d$h)
  d$dist  <- nearest_knot_dist(d$t)
  d$distN <- d$dist / d$h           # distance to knot in units of the step
  acc <- d[d$ok == 1, ]; rej <- d[d$ok == 0, ]

  # among sub-knot steps (h < DK, so they CAN sit between knots): is the
  # start near a knot? "near" = within 10% of a step of a knot.
  subk_acc <- acc[acc$h < DK, ]; subk_rej <- rej[rej$h < DK, ]
  near_acc <- if (nrow(subk_acc)) mean(subk_acc$dist < 0.1 * subk_acc$h) else NA
  near_rej <- if (nrow(subk_rej)) mean(subk_rej$dist < 0.1 * subk_rej$h) else NA

  cat(sprintf("%-18s %7d %6.1f %8.2f %8.2f %8.3f %8.3f %8s %8s\n",
      nm, nrow(d), 100 * mean(d$ok == 0),
      median(acc$hDK), quantile(acc$hDK, 0.10),
      mean(acc$nk >= 1), mean(rej$nk >= 1),
      ifelse(is.na(near_acc), "-", sprintf("%.3f", near_acc)),
      ifelse(is.na(near_rej), "-", sprintf("%.3f", near_rej))))

  allrows[[nm]] <- data.frame(
    scen = nm, n = nrow(d), rejpct = 100 * mean(d$ok == 0),
    medH_DK = median(acc$hDK), p10H_DK = as.numeric(quantile(acc$hDK, 0.10)),
    span_acc = mean(acc$nk >= 1), span_rej = mean(rej$nk >= 1),
    frac_subknot_acc = mean(acc$h < DK), frac_subknot_rej = mean(rej$h < DK),
    near_acc = near_acc, near_rej = near_rej)
}

cat("\nLegend: medH/DK,p10H/DK = median & 10th-pct accepted step in knot",
    "spacings;\n  spanAcc/spanRej = frac of accepted/rejected attempts whose",
    "trial interval\n  spans >=1 daily knot; subK_acc/rej = among sub-knot",
    "steps, frac starting within 10% of a knot.\n")

summ <- do.call(rbind, allrows)
saveRDS(summ, "scripts/tf24-benchmarks/results/node_distance_summary.rds")
cat("\nfrac of ALL accepted steps that are sub-knot (h<DK):\n")
print(round(setNames(summ$frac_subknot_acc, summ$scen), 4))
