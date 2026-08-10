# Is the light floor reachable by raising the extinction coefficient?
#
# The floor on light binds when k_I * LAI >= ln(1e4) = 9.2103. Reports 03, 05,
# 06 and 07 all carry the hazard that k_I is a registered free parameter, so a
# calibration or a gradient-ascent run can walk the field into the region where
# the row it is ascending goes to zero.
#
# That presumes k_I * LAI rises with k_I. This measures whether it does.
#
# WHAT WOULD MAKE THIS PROBE UNABLE TO FAIL (METHOD.md 1, 9.0):
#   The parameter not reaching the model. It is `pars$k_I`, one level below the
#   strategy; assigning `strategy$k_I` silently creates a new R list element
#   that the C++ side never reads, and every arm then returns the SAME number.
#   A first version of this script did exactly that and reported k_I * LAI
#   identical to four decimals across a twelvefold change in k_I, with identical
#   step counts -- which reads as "self-shading exactly cancels" and is in fact
#   "nothing was varied". The assertions below exist to catch that.
#
# Route note: this uses add_strategies, whose R-side derivation differs from the
# C++ initialisers (report 07 section 3). That is sound for a forward LAI
# measurement and would NOT be sound for a gradient reference.
#
# Usage: R_LIBS_USER=/home/user/lib-verify Rscript scripts/measure/kI-lai-invariance.R
suppressMessages({
  library(odelia); library(plant)
  attach(asNamespace("plant"), name = "plant-internals")  # METHOD.md 4
})

LIFETIME <- 30
LMA      <- 0.0825
K_I      <- c(0.5, 1.0, 2.0, 3.0, 3.5, 6.0)
FLOOR    <- log(1e4)

cat(sprintf("lifetime=%s lma=%s  floor binds at k_I*LAI >= %.4f\n\n",
            LIFETIME, LMA, FLOOR))
cat(sprintf("%6s %10s %12s %8s %8s %s\n",
            "k_I", "k_I*LAI", "implied LAI", "steps", "secs", "note"))

rows <- list()
for (k in K_I) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA, "lma"))

  pars <- p$strategies[[1]]$pars
  pars$k_I <- k
  p$strategies[[1]]$pars <- pars

  # GUARD 1: the parameter must have taken, or the arm is meaningless.
  got <- p$strategies[[1]]$pars$k_I
  stopifnot(is.numeric(got), length(got) == 1, isTRUE(all.equal(got, k)))

  t0  <- proc.time()[["elapsed"]]
  res <- try(run_scm(p), silent = TRUE)
  el  <- proc.time()[["elapsed"]] - t0

  if (inherits(res, "try-error")) {
    cat(sprintf("%6.2f %10s %12s %8s %8.1f  ERROR %s\n", k, "-", "-", "-", el,
                sub("\n.*", "", conditionMessage(attr(res, "condition")))))
    next
  }

  kL     <- res$patch$species[[1]]$compute_competition(0)
  steps  <- length(res$ode_times)
  reach  <- res$patch$environment$time
  rows[[length(rows) + 1]] <- c(k = k, kL = kL, steps = steps)

  cat(sprintf("%6.2f %10.4f %12.4f %8d %8.1f  t=%.1f%s%s\n",
              k, kL, kL / k, steps, el, reach,
              if (reach < LIFETIME * 0.99) "  DID NOT COMPLETE" else "",
              if (kL >= FLOOR) "  FLOOR BINDS" else ""))
}

# GUARD 2: if every arm agrees to four decimals, suspect the harness, not the
# ecology. Distinct k_I with identical k_I*LAI AND identical step counts is the
# signature of a parameter that never reached the model.
if (length(rows) > 1) {
  m  <- do.call(rbind, rows)
  kL <- round(m[, "kL"], 4)
  st <- m[, "steps"]
  if (length(unique(kL)) == 1L && length(unique(st)) == 1L)
    stop("HARNESS DEFECT: every arm returned identical k_I*LAI and identical ",
         "step counts. k_I did not reach the model. Do not report these numbers.")
  cat(sprintf("\nk_I*LAI spread: %.4f to %.4f over k_I %.2f to %.2f\n",
              min(m[, "kL"]), max(m[, "kL"]), min(m[, "k"]), max(m[, "k"])))
  cat(sprintf("floor threshold %.4f %s\n", FLOOR,
              if (max(m[, "kL"]) >= FLOOR) "IS reached" else "is NOT reached in this range"))
}
