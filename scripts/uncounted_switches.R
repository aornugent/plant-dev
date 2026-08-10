# Incidence, on a production TF24 run, of four discrete constructs that no
# report has counted. All four are read off aux slots and heights, so no
# instrumentation is needed.
#
#   1. max_soil_layer < soil_number_of_depths -- the shallow-rooted regime in
#      which soil_consumption_'s deep layers are never written this solve and
#      therefore carry the previously-solved cohort's values (see
#      scripts/leaf_state_carryover.R for the mechanism). The criterion is a
#      height threshold: with 5 layers over 1.5 m, mass_root_prop_[4] is zero
#      once rooting_depth = min(height, 1.5) falls at or below 1.2 m.
#   2. the `assimilation` aux slot, declared in aux_names() but written
#      nowhere -- it should be a constant 0 for every record.
#   3. Species::consumption_rate's `size() < 2` early return, which hands the
#      soil exactly zero uptake for a species with one cohort.
#   4. the light floor max(light, 1e-4) in compute_average_light_environment
#      and radiation_at, a derivative severance wherever it binds.
#
#   Rscript scripts/uncounted_switches.R [life]

suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-develop", quiet = TRUE)
})
life <- as.numeric(commandArgs(TRUE)[1]); if (is.na(life)) life <- 105.32

p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- life
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))

t0 <- Sys.time()
res <- run_scm(p, Environment("TF24"), Control(), collect = TRUE,
               refine_schedule = FALSE)
el <- as.numeric(Sys.time() - t0, "secs")

d <- as.data.frame(res$species)
n <- nrow(d)
cat(sprintf("life %.2f, %.1f s, %d cohort-time records, %d steps\n\n",
            life, el, n, nrow(res$steps)))

n_layers <- 5
soil_z   <- (1:n_layers) * (1.5 / n_layers)
root_eta <- 0.2

max_soil_layer <- function(height) {
  rd <- pmin(height, 1.5)
  out <- integer(length(height))
  for (k in seq_along(height)) {
    prev_q <- 1; m <- 0L
    for (a in seq_len(n_layers)) {
      if (prev_q == 0) break
      q <- if (soil_z[a] > rd[k]) 0 else (1 - (soil_z[a] / rd[k])^root_eta)^2
      if (prev_q - q != 0) m <- a
      prev_q <- q
    }
    out[k] <- m
  }
  out
}

h <- d$height[is.finite(d$height)]
msl <- max_soil_layer(h)

cat("=== 1. shallow-rooted solves (deep soil_consumption_ layers stale) ===\n")
for (k in seq_len(n_layers)) {
  cat(sprintf("  max_soil_layer == %d : %8d  (%6.2f%%)\n",
              k, sum(msl == k), 100 * mean(msl == k)))
}
cat(sprintf("\n  at least one stale deep layer : %8d  (%6.2f%%)\n",
            sum(msl < n_layers), 100 * mean(msl < n_layers)))
cat(sprintf("  height <= 1.2 m               : %8d  (%6.2f%%)\n",
            sum(h <= 1.2), 100 * mean(h <= 1.2)))
cat(sprintf("  min / median / max height     : %.4e / %.4f / %.4f m\n",
            min(h), median(h), max(h)))

cat("\n=== 2. the never-written `assimilation` aux ===\n")
if ("assimilation" %in% names(d)) {
  a <- d$assimilation
  cat(sprintf("  present, range [%s, %s], all exactly 0: %s\n",
              format(min(a)), format(max(a)), all(a == 0)))
} else {
  cat(sprintf("  not in the collected output; aux names present:\n    %s\n",
              paste(names(d), collapse = ", ")))
}

cat("\n=== 3. the size() < 2 water switch ===\n")
# A species has one cohort from its introduction until the next introduction.
tt <- res$time
n_by_time <- tapply(d$height[is.finite(d$height)],
                    d$time[is.finite(d$height)], length)
cat(sprintf("  distinct output times                 : %d\n", length(n_by_time)))
cat(sprintf("  times with exactly 1 live cohort      : %d  (%.2f%%)\n",
            sum(n_by_time == 1), 100 * mean(n_by_time == 1)))
cat(sprintf("  cohort count at the first output time : %d\n", n_by_time[1]))
cat("  (at those times the patch draws exactly zero water from a\n")
cat("   transpiring plant, and the soil integrates as if unplanted)\n")

cat("\n=== 4. the 1e-4 light floor ===\n")
env <- as.data.frame(res$env)
if ("light_availability" %in% names(env)) {
  la <- env$light_availability
  la <- la[is.finite(la)]
  cat(sprintf("  light knot values: min %.4e, %d of %d at or below 1e-4 (%.2f%%)\n",
              min(la), sum(la <= 1e-4), length(la), 100 * mean(la <= 1e-4)))
  cat(sprintf("  fraction below 1e-3: %.2f%%\n", 100 * mean(la <= 1e-3)))
} else {
  cat(sprintf("  env columns: %s\n", paste(names(env), collapse = ", ")))
}

cat("\n=== E_up_ aux, for reference (kg H2O m^-2 leaf s^-1) ===\n")
e <- d$E_up_[is.finite(d$E_up_)]
cat(sprintf("  min %.4e  median %.4e  max %.4e  negative: %d\n",
            min(e), median(e), max(e), sum(e < 0)))
