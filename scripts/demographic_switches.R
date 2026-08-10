# Incidence of the demographic, field-reduction and root-water discrete constructs
# that P0.5's second table lists without numbers, plus three of the four items on
# its "still to count" list.
#
# CONFIGURATION
#   plant develop 141dc8df in the worktree /home/user/wt-switch-inventory, built -O2
#   with the counters of /home/user/p0/p0.5-instrumentation.patch applied. One
#   species (lma = 0.1978791), TF24 / TF24_Env, five soil layers, default driver,
#   default Control (GSS_tol_abs = 1e-3), max_patch_lifetime = 105.32 set on the
#   BASE parameters before add_strategies, refine_schedule = FALSE, collect = TRUE.
#   That run is 10 153 cohort-time records over 142 output times.
#
#   The counters are per C++ call, so they carry their own denominators (calls of
#   the enclosing function) and are not fractions of 10 153. The R-side sections
#   below use the 10 153 records and 142 output times.
#
#   Rscript scripts/demographic_switches.R          # counters, needs the patch
#
#   PLANT_SWITCH_PROBE=1                            # every counter below
#   PLANT_SWITCH_PROBE=1 PLANT_SWITCH_PROBE_NMP=1   # adds net_mass_production_dt
#     at height_0 wherever pr_estab == 0. That is one extra solve on the shared
#     Leaf, so it perturbs the run (root_loop calls move 7 551 699 -> 7 559 578);
#     take every other counter from the arm without it.
#
# The constructs counted in C++:
#   Species::compute_competition  -- the `h0 < height` break and the
#     `size() == 1 || f_h1 > 0` boundary-node arm, with the resulting term count
#   Patch::compute_environment    -- `size() > 0 & !is_mutant_run`
#   Node::compute_rates           -- `!is_finite(survival_individual) -> 0`
#   Node::compute_initial_conditions -- `g > 0 ? log(...) : log(0)` and the
#     `!is_finite(log_density) -> log_density_dt = 0` follow-up, with the two
#     factors of the numerator counted separately so the zero is attributable:
#     `birth_rate == 0` against `pr_estab == 0`, the latter being
#     establishment_probability's `net_mass_production_dt_ > 0` gate
#   TF24_Strategy::mortality_dt   -- `is_finite(cumulative_mortality)`
#   the root-distribution loop    -- the `prev_q == 0` exact-double break
#   E_from_Soil_to_Root_Collar    -- which of the three branches each layer takes,
#     and whether the magnitude fed to the root vulnerability splines crosses the
#     fitted domain edge beyond which root_vuln_from_psi extrapolates negative
#
# The root-distribution loop is the loop scripts/uncounted_switches.R already
# replays as max_soil_layer(), so the record-level number here is that probe's:
# break at a = k is max_soil_layer == k - 1.
#
# RESULTS  (234.2 s; stderr SWITCHPROBE lines)
#   species.compute_competition  calls 3 075 900; h0 < height break 2 989 227
#     (97.18%); ran to end 86 574 (2.82%); early return 99; boundary arm 74 060
#     (2.41%), of which 627 via size() == 1 and 73 433 via f_h1 > 0; skipped
#     3 001 741 (97.59%); smallest positive f_h1 that took the arm 2.714503e-11;
#     216 594 704 trapezium terms, at most 141 in one call
#   patch.compute_environment    35 274 calls, 35 274 rebuilt (100%), 0 empty,
#     0 mutant
#   node.compute_rates           3 758 283 calls; survival_individual non-finite
#     0; survival_individual exactly 0 185 851 (4.95%); largest finite
#     cumulative mortality 545.06
#   node.compute_initial_conditions  35 133 calls (once per species per Runge-Kutta
#     stage, against 141 introductions); g <= 0 zero times, g_min 0.09529771 m/yr;
#     log_density non-finite 7 879 (22.43% of stage evaluations)
#   zero_numerator  of those 7 879, birth_rate == 0 on 0 and pr_estab == 0 on
#     7 879; both zero on 0. Confined to t in [3.222267, 8.544184], the first
#     tenth of the lifetime, and absent from every later bin
#   nmp_at_height_0 (PLANT_SWITCH_PROBE_NMP arm only, which perturbs the shared
#     Leaf) net_mass_production_dt at height_0 on those 7 879 calls: all negative,
#     min -3.352987e-05, max -2.283012e-09, mean -2.063678e-05
#   mortality_dt                 7 516 566 calls; cumulative_mortality
#     non-finite 371 702 (4.95%); largest finite value 545.06
#   root_loop                    7 551 699 calls; prev_q == 0 break 767 291
#     (10.16%), at a = 3 / 4 / 5 in 403 873 / 188 566 / 174 852
#   E_from_Soil_to_Root_Collar   1 162 082 517 layer evals; equal-potentials
#     branch 15 109 531 (1.30%); gravity-balanced branch 0; general branch
#     1 146 972 986 (98.70%); beyond the fitted domain 0; largest magnitude fed
#     to the splines 5.919880 MPa against a last knot at 6.822923 MPa
#   R side: 327 of 10 153 records (3.22%) hold cumulative mortality Inf, none
#     before t = 3.5 and 6 per output time from t = 7 on; |opt_root_psi| max
#     2.359889 MPa; the prev_q break fires on 3 430 of 10 153 records (33.78%)

suppressMessages({
  library(odelia)
  pkgload::load_all("/home/user/wt-switch-inventory", quiet = TRUE)
})

p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 105.32
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))

t0 <- Sys.time()
r <- run_scm(p, Environment("TF24"), Control(), collect = TRUE,
             refine_schedule = FALSE)
el <- as.numeric(Sys.time() - t0, "secs")

d <- as.data.frame(r$species)
cat(sprintf("run %.1f s, %d cohort-time records, %d output times\n\n",
            el, nrow(d), length(unique(d$time))))
cat("columns: ", paste(names(d), collapse = ", "), "\n\n")

# --- survival_individual, as a function of time rather than a percentage ------
cat("=== survival_individual = exp(-mortality), by output time ===\n")
if ("mortality" %in% names(d)) {
  m <- d$mortality
  s <- exp(-m)
  cat(sprintf("  mortality: min %.4e median %.4f max %.4f, non-finite %d\n",
              min(m, na.rm = TRUE), median(m, na.rm = TRUE),
              max(m, na.rm = TRUE), sum(!is.finite(m))))
  cat(sprintf("  exp(-mortality): min %.4e, exactly 0 (underflow) %d, non-finite %d\n",
              min(s, na.rm = TRUE), sum(s == 0, na.rm = TRUE), sum(!is.finite(s))))
  cat(sprintf("  mortality > 709 (exp underflows to 0): %d of %d (%.2f%%)\n",
              sum(m > 709, na.rm = TRUE), length(m),
              100 * mean(m > 709, na.rm = TRUE)))
  tt <- sort(unique(d$time))
  q <- sapply(tt, function(x) {
    z <- d$mortality[d$time == x]
    c(n = length(z), max = max(z, na.rm = TRUE),
      n745 = sum(z > 709, na.rm = TRUE))
  })
  cat("  per output time: max cumulative mortality and count above 709\n")
  idx <- unique(round(seq(1, length(tt), length.out = 12)))
  for (i in idx) {
    cat(sprintf("    t = %8.3f  nodes %4d  max mortality %10.4f  above 709: %d\n",
                tt[i], q["n", i], q["max", i], q["n745", i]))
  }
  cat(sprintf("  max cumulative mortality over the whole run: %.4f at t = %.3f\n",
              max(q["max", ]), tt[which.max(q["max", ])]))
} else {
  cat("  no mortality column\n")
}

# --- the root vulnerability domain edge, from R -------------------------------
cat("\n=== root vulnerability domain edge, checked independently in R ===\n")
root_b <- 3.898245; root_c <- 2.680147
edge <- root_b * (log(1 / 0.01))^(1 / root_c)
cat(sprintf("  psi_max_root = root_b * log(100)^(1/root_c) = %.6f MPa\n", edge))
if ("opt_root_psi" %in% names(d)) {
  x <- d$opt_root_psi[is.finite(d$opt_root_psi)]
  cat(sprintf("  |opt_root_psi|: max %.6f MPa over %d records, margin to edge %.6f MPa (%.2fx)\n",
              max(abs(x)), length(x), edge - max(abs(x)), edge / max(abs(x))))
}
cat("  psi_soil is not convertible from R (psi_from_soil_moist is not exported), so\n")
cat("  the magnitude actually fed to the splines is taken from the SWITCHPROBE\n")
cat("  E_from_soil line, which maxes it over every layer eval including the\n")
cat("  root-find iterates that the output-time census does not see.\n")

# --- prev_q == 0, replayed in R for the layer index -------------------------
cat("\n=== the prev_q == 0 break, replayed in R ===\n")
n_layers <- 5
soil_z <- (1:n_layers) * (1.5 / n_layers)
root_eta <- 0.2
Qf <- function(z, h, eta) if (z > h) 0 else (1 - (z / h)^eta)^2
brk <- function(height) {
  rd <- min(height, 1.5); prev_q <- 1
  for (a in seq_len(n_layers)) {
    if (prev_q == 0) return(a)
    prev_q <- Qf(soil_z[a], rd, root_eta)
  }
  0L
}
h <- d$height[is.finite(d$height)]
b <- vapply(h, brk, integer(1))
cat(sprintf("  records where the break fires: %d of %d (%.2f%%)\n",
            sum(b > 0), length(h), 100 * mean(b > 0)))
for (a in seq_len(n_layers)) {
  if (sum(b == a) > 0)
    cat(sprintf("    break at a = %d : %6d (%.2f%%)\n",
                a, sum(b == a), 100 * mean(b == a)))
}
cat(sprintf("  heights at which it fires: max %.4f m (rooting_depth < %.2f m)\n",
            if (any(b > 0)) max(h[b > 0]) else NA_real_, soil_z[n_layers]))

# --- boundary node and the descending sweep, R-side context -----------------
cat("\n=== node counts per output time (context for species.h:215 and :220) ===\n")
nb <- table(d$time[is.finite(d$height)])
cat(sprintf("  nodes per output time: min %d max %d mean %.1f\n",
            min(nb), max(nb), mean(nb)))
cat(sprintf("  output times with exactly one node: %d of %d\n",
            sum(nb == 1), length(nb)))
cat("\n(the SWITCHPROBE lines on stderr carry the per-call counts)\n")
