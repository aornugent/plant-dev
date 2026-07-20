# Stage-1 classifier -- ANALYZE pass (cheap; iterate freely on saved raw data).
#
# Reads results/classifier_raw/<scenario>.rds (from classifier_capture.R) and
# decides the gate: is step-collapse driven by REMOVABLE discrete events (that a
# step-to-event stepper could locate and eliminate) or by INTRINSIC fast
# structure (that it cannot)?
#
# The gate rests on three direct, threshold-light measurements -- NOT on a
# saturated "near any surface" heuristic (6 one-sided margins x a decile band
# fires on ~40% of all steps and cannot discriminate):
#
#  1. DO the hypothesized event surfaces even get approached? Report the closest
#     each margin ever comes to its event zero. A surface whose margin never
#     nears zero cannot be causing collapse.
#  2. DO discrete events (per-cohort branch-code flips, soil-clamp/runoff bit
#     changes) co-locate with collapse? Report the share of rejection attempts
#     (the R2 waste) and small accepted steps within +/-1 step of a flip. Low
#     share => collapse is not the events.
#  3. WHAT predicts step size / rejections? Spearman(log h, margin) and
#     Spearman(n_reject, margin). A discrete event would show as collapse
#     concentrated at a margin's zero; a monotone rho vs a wetness margin is
#     continuous stiffness, not a locatable event.

rawdir <- "scripts/tf24-benchmarks/results/classifier_raw"
files <- list.files(rawdir, pattern = "\\.rds$", full.names = TRUE)
if (length(files) == 0) stop("no raw data in ", rawdir, " -- run classifier_capture.R")

MARGINS <- c("theta_res", "theta_sat", "psi_ceil", "runoff", "shutdown",
             "interval", "psi_wettest")
FLIP_COLS <- c("clamp_bits", "runoff_on", paste0("branch", 0:5))

analyze_one <- function(r) {
  mon <- r$mon; log <- r$log
  if (is.null(mon) || nrow(mon) < 10) return(NULL)   # skip failed/aborted runs
  n <- nrow(mon)

  rej <- log[log$ok == 0, , drop = FALSE]
  n_reject <- tabulate(match(rej$t, mon$t), nbins = n); n_reject[is.na(n_reject)] <- 0
  small <- mon$h <= as.numeric(quantile(mon$h, 0.25))

  # 1. closest approach of each surface to its event zero (one-sided margins:
  #    event at 0; smaller = nearer). psi_wettest is informational (wetness).
  approach <- sapply(MARGINS, function(c) min(mon[[c]][is.finite(mon[[c]])]))

  # 2. discrete-event flips and their co-location with collapse
  flip <- rep(FALSE, n)
  for (c in FLIP_COLS) { v <- mon[[c]]; flip <- flip | (v != c(v[1], v[-n])) }
  flip_win <- flip | c(FALSE, flip[-n]) | c(flip[-1], FALSE)   # +/-1 window
  rej_near_event <- sum(n_reject[flip_win]) / max(1, sum(n_reject))
  small_near_event <- sum(small & flip_win) / max(1, sum(small))
  # discrete event surfaces that ever fire
  shutdown_rows <- sum(rowSums(mon[, paste0("branch", 0:3)]) > 0)
  branch5_frac <- sum(mon$branch5) / max(1, sum(mon[, paste0("branch", 0:5)]))

  # 3. what predicts collapse
  rho_h <- sapply(MARGINS, function(c) {
    v <- mon[[c]]; ok <- is.finite(v)
    suppressWarnings(cor(log(mon$h[ok]), v[ok], method = "spearman"))
  })
  rho_rej <- sapply(MARGINS, function(c) {
    v <- mon[[c]]; ok <- is.finite(v)
    suppressWarnings(cor(n_reject[ok], v[ok], method = "spearman"))
  })

  list(scenario = r$scenario, n = n, rej_frac = mean(log$ok == 0),
       min_h_days = min(mon$h) * 365, approach = approach,
       shutdown_rows = shutdown_rows, branch5_frac = branch5_frac,
       rej_near_event = rej_near_event, small_near_event = small_near_event,
       rho_h = rho_h, rho_rej = rho_rej)
}

rows <- lapply(files, function(f) analyze_one(readRDS(f)))
rows <- Filter(Negate(is.null), rows)

for (a in rows) {
  cat(sprintf("\n=== %s ===\n", a$scenario))
  cat(sprintf("  accepted=%d rej_frac=%.3f min_h=%.4f d | branch5=%.4f shutdown_rows=%d\n",
              a$n, a$rej_frac, a$min_h_days, a$branch5_frac, a$shutdown_rows))
  cat("  closest approach to each surface (one-sided margin min):\n    ")
  cat(paste(sprintf("%s=%.3g", names(a$approach), a$approach), collapse = "  "), "\n")
  cat(sprintf("  rejection attempts within +/-1 of a discrete event: %.0f%%\n",
              100 * a$rej_near_event))
  cat(sprintf("  small steps within +/-1 of a discrete event: %.0f%%\n",
              100 * a$small_near_event))
  cat("  Spearman(log h, margin): ")
  cat(paste(sprintf("%s=%+.2f", names(a$rho_h), a$rho_h), collapse = " "), "\n")
}

cat("\n===== GATE SUMMARY =====\n")
tab <- do.call(rbind, lapply(rows, function(a) data.frame(
  scenario = a$scenario, rej_frac = round(a$rej_frac, 3),
  branch5_frac = round(a$branch5_frac, 4),
  min_shutdown = round(a$approach["shutdown"], 2),
  min_theta_res = round(a$approach["theta_res"], 3),
  rej_near_event = round(a$rej_near_event, 3),
  small_near_event = round(a$small_near_event, 3))))
print(tab, row.names = FALSE)

med_rej_near <- median(tab$rej_near_event)
cat(sprintf("\nmedian rejection-attempts-near-event = %.0f%% | median shutdown min-margin = %.2f\n",
            100 * med_rej_near, median(tab$min_shutdown)))
cat(if (med_rej_near >= 0.5)
      "GATE: collapse co-locates with discrete events -> build Stage 2 (event stepper).\n"
    else
      paste0("GATE: collapse does NOT co-locate with discrete events, and the ",
             "hypothesized surfaces are never approached\n      -> INTRINSIC fast ",
             "structure. Do NOT build the event-location stepper; keep the forcing\n",
             "      clip, consider the cheap proximity governor for the reject ",
             "fraction, and move to the mesh/J frontier (spec sec 7).\n"))

saveRDS(tab, "scripts/tf24-benchmarks/results/classifier_gate.rds")
