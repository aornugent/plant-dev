#   Rscript scripts/m3b_cohort_tops.R
#
# M3b. What do fixed fractions cost against knots at the cohort tops?
#
# Two knot placements are on the table and the reports argue them in different
# places. Fixed fractions (build-plan section 2.6, report 03 section 1b) hold the
# interpolant on u = z / height_max with the fractions constant for the run, which
# is what rescale_spline's affine remap already computes and what makes the knot
# positions run-constant doubles. Knots at the cohort tops (report 03 section 5.3,
# report 01 section 7.6) put a knot exactly where the field's derivative breaks,
# because L = exp(-A) and each cohort contributes Q(z/h) whose slope jumps at
# z = h -- and report 03 measures O(h^4) on value and O(h^3) on slope with that
# placement.
#
# So the trade is: alignment with the kinks against run-constant positions. This
# probe prices both sides on one production run.
#
#   C1  crown-mean light error, uniform fractions against cohort tops at the same
#       count, and against cohort tops at their natural count
#   C2  the span ratio each placement produces -- min span over domain. A Hermite
#       divides by the span width, so a collapsing span is the cohort-top
#       placement's own failure mode, and report 01 section 7.6 records that its
#       refutation in a toy does not survive on the model
#   C3  how the cohort-top count moves through the run, since a knot count that
#       changes is a recorded-computation shape that changes
#
# CONFIGURATION. Identical to scripts/m3_fixed_fractions.R so the numbers compose:
# plant develop 141dc8df, odelia 854a8e18, -O2 -DNDEBUG, one TF24 strategy at lma
# 0.1978791, Control(), refine_schedule = FALSE, max_patch_lifetime = 105.32,
# collect = TRUE, eta = 12, Gauss-Legendre 15 for the crown integral. The reference
# is develop's own knot data per step, splined in R; a candidate is that field
# resampled onto the candidate positions. So this compares PLACEMENTS, not spline
# implementations, and the errors are shifts against develop rather than accuracy
# against the true field.
#
# RESULTS. 141 steps. The cohort-top count runs 3 to 143, mean 73.0.
#
#   placement           knots      median         p95         max   worst span
#   uniform 65             65    1.646e-06   1.883e-04   1.699e-03    1.562e-02
#   uniform matched     3-143    2.719e-07   3.525e-05   7.194e-04    7.042e-03
#   cohort tops         3-143    6.929e-06   7.597e-03   1.598e-02    1.278e-06
#
# Cohort tops are WORSE, at the same knot count, by 22x at the max and 215x at the
# 95th percentile -- and their worst span is four orders narrower.
#
# The reason is that cohort heights cluster and the field's curvature does not. A
# stand's cohorts bunch: the minimum interior spacing is 8.2e-06 m on a 17.9 m
# domain, 4.6e-07 of it (report 04 section 5). So a knot per cohort top puts many
# knots inside one bunch and leaves the gaps between bunches unresolved, and it is
# the gaps that carry the error. The field bends where leaf area is, which is not
# where cohort tops are.
#
# This also confirms on the model what report 01 section 7.6 could only refute in a
# toy: the collapsing-span hazard is real. Worst span ratio 1.278e-06 against
# uniform's 7.042e-03, and a Hermite divides by the span width.
#
# Report 03 section 5.3's O(h^4) is not contradicted -- it subdivides cohort-top
# spans uniformly to 142, 283 and 565 knots, so the kinks sit on knots AND the
# spans are refined. That is the placement's asymptotic rate. What this measures is
# the constant at a count a production run can afford, and there uniform wins.
#
# So fixed uniform fractions cost nothing in accuracy against the alignment they
# give up. They are not a purity tax paid for the reverse pass -- they are also
# the better placement, and the third column is the argument.

suppressMessages({ library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE) })

p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 105.32
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
r <- run_scm(p, Environment("TF24"), Control(), collect = TRUE, refine_schedule = FALSE)

eta <- TF24_Strategy()$pars$eta
la <- r$env$light_availability
sp <- r$species
steps <- sort(unique(la$step))

gl_x <- c(-0.9879925180204854, -0.9372733924007060, -0.8482065834104272,
          -0.7244177313601701, -0.5709721726085388, -0.3941513470775634,
          -0.2011940939974345,  0.0,                 0.2011940939974345,
           0.3941513470775634,  0.5709721726085388,  0.7244177313601701,
           0.8482065834104272,  0.9372733924007060,  0.9879925180204854)
gl_w <- c(0.0307532419961173, 0.0703660474881081, 0.1071592204671719,
          0.1395706779261543, 0.1662692058169939, 0.1861610000155622,
          0.1984314853271116, 0.2025782419255613, 0.1984314853271116,
          0.1861610000155622, 0.1662692058169939, 0.1395706779261543,
          0.1071592204671719, 0.0703660474881081, 0.0307532419961173)
xi <- 0.5 * (gl_x + 1); w <- 0.5 * gl_w
kern <- 2 * eta * (1 - xi^eta) * xi^(eta - 1)
crown_mean <- function(f, h) sum(w * f(h * xi) * kern)

# Positions for each placement, in absolute height, given a step's knot span and
# that step's cohort heights.
placements <- function(hmax, hs) {
  tops <- sort(unique(c(0, hs[hs > 0 & hs < hmax], hmax)))
  n <- length(tops)
  list(
    `uniform 65`      = seq(0, hmax, length.out = 65),
    `uniform matched` = seq(0, hmax, length.out = n),
    `cohort tops`     = tops)
}

acc <- list(); spans <- list(); counts <- integer(0)
for (s in steps) {
  k <- la[la$step == s, ]; k <- k[order(k$height), ]
  if (nrow(k) < 4) next
  hmax <- max(k$height)
  ref <- splinefun(k$height, k$light_availability, method = "natural")
  hs <- sp$height[sp$step == s]; hs <- hs[hs > 0]
  if (length(hs) < 2) next
  ref_means <- vapply(hs, function(h) crown_mean(ref, h), numeric(1))

  pl <- placements(hmax, hs)
  counts <- c(counts, length(pl[["cohort tops"]]))
  for (nm in names(pl)) {
    z <- pl[[nm]]
    if (length(z) < 4) next
    cand <- splinefun(z, ref(z), method = "natural")
    cm <- vapply(hs, function(h) crown_mean(cand, h), numeric(1))
    acc[[nm]] <- c(acc[[nm]], abs(cm - ref_means) / ref_means)
    spans[[nm]] <- c(spans[[nm]], min(diff(z)) / hmax)
  }
}

cat(sprintf("%d steps, cohort-top knot count %d to %d (mean %.1f)\n\n",
            length(counts), min(counts), max(counts), mean(counts)))
cat("C1  crown-mean light: |candidate - develop| / develop, every cohort record\n")
cat("C2  span ratio: min span / domain, worst over steps\n\n")
cat(sprintf("%-18s %12s %12s %12s %14s\n", "placement", "median", "p95", "max",
            "worst span"))
for (nm in names(acc))
  cat(sprintf("%-18s %12.3e %12.3e %12.3e %14.3e\n", nm,
              median(acc[[nm]]), quantile(acc[[nm]], 0.95), max(acc[[nm]]),
              min(spans[[nm]])))
