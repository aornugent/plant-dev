# What sets the steps of the long-drought stand (harness/long_drought.R) under
# Cash-Karp: J and the attempt tallies at one tolerance, and with RECORD=1 the
# component binding each accepted step, the soil chain's stiffness there and
# the step sizes by leg. The stepper scope's section 4 quotes these on v12.
#
#   PLANT_LIB=... NODES=108 TOL=1e-3 RECORD=1 OUT=u108.rds \
#     [STATES=u108_states.rds] Rscript harness/v12_steps.R
#
# STATES keeps every recorded state, which harness/soil_bound.R reads.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
nodes <- as.integer(Sys.getenv("NODES", "108"))
tol <- as.numeric(Sys.getenv("TOL", "1e-3"))
record <- Sys.getenv("RECORD", "0") == "1"
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(uniform_times(nodes))
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(AK))))
t0 <- proc.time()[["elapsed"]]
scm <- run_scm(p, mkenv(), ct, events = ev, record_trajectory = record)
att <- scm$ode_step_attempts
out <- list(nodes = nodes, tol = tol, J = sum(scm$offspring_production),
            attempts = att, secs = proc.time()[["elapsed"]] - t0)
cat(sprintf("nodes %d tol %g: J %.9f, %d accepted, %.0f s; %s\n", nodes, tol, out$J,
            att[["accepted"]], out$secs,
            paste(names(att), att, sep = "=", collapse = " ")))

if (record) {
  tr <- scm$store_trajectory()
  # On the birth-date coordinate a node holds nine states (its eight and its
  # establishment mass), and the environment's ten close the state: five soil
  # layers, then the five flux accumulators.
  w <- vapply(tr, function(r) length(r$state), 0L)
  stopifnot(all((w - 10L) %% 9L == 0L))
  rows <- data.frame(
    time = vapply(tr, function(r) r$time, 0),
    h = vapply(tr, function(r) r$step_size, 0),
    ins = vapply(tr, function(r) isTRUE(r$introduction), TRUE),
    ei = vapply(tr, function(r) as.integer(r$error_index), 0L),
    er = vapply(tr, function(r) r$error_ratio, 0),
    w = w, M = (w - 10L) %/% 9L)
  soil <- t(vapply(tr, function(r) r$state[length(r$state) - 9:5], numeric(5)))
  colnames(soil) <- paste0("soil_", 1:5)
  rows <- cbind(rows, soil)
  if (nzchar(Sys.getenv("STATES"))) {
    saveRDS(lapply(tr, function(r) r$state), Sys.getenv("STATES"), compress = FALSE)
  }
  rm(tr)

  NODE <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
            "storage", "offspring", "log_density", "mass")
  ENV <- c(paste0("soil_", 1:5), paste0("accumulator_", 1:5))
  acc <- which(!rows$ins & !is.na(rows$h))
  st <- rows[acc, ]
  st$row <- acc
  j <- st$ei; m <- st$M
  st$kind <- ifelse(j <= 9L * m, NODE[(j - 1L) %% 9L + 1L], ENV[pmax(1L, j - 9L * m)])

  # The soil chain's diagonal at each step's start: drainage, and on the top
  # layer the infiltration term while it is below saturation.
  theta_s <- 0.428; K_sat <- 163.0411; q <- 2 * 6.57 + 3; b_inf <- 8; dz <- 1.5 / 5
  BETA <- 3.7343596   # Cash-Karp's real stability boundary
  th <- as.matrix(rows[acc - 1L, paste0("soil_", 1:5)])
  rain <- mkenv()$extrinsic_drivers_evaluate_range("rainfall", rows$time[acc - 1L])
  lam <- ifelse(th > 0 & th <= theta_s, q * K_sat * (th / theta_s)^q / (th * dz), 0)
  lam[, 1] <- lam[, 1] + ifelse(th[, 1] < theta_s,
                                rain * b_inf * (th[, 1] / theta_s)^b_inf / (th[, 1] * dz), 0)
  st$soil_lam <- apply(lam, 1, max)
  st$x_soil <- st$h * st$soil_lam / BETA

  pct <- function(x) sprintf("%.1f%%", 100 * mean(x))
  cat("binding: soil", pct(grepl("^soil_", st$kind)), " member", pct(st$kind %in% NODE),
      " storage", pct(st$kind == "storage"), "\n")
  cat("h |lambda_soil| / beta >= 0.5:", pct(st$x_soil >= 0.5), " >= 0.8:", pct(st$x_soil >= 0.8),
      " > 1:", pct(st$x_soil > 1), "\n")
  cat("median error ratio by h |lambda_soil| / beta (<0.5, 0.5-0.8, 0.8-1, 1-1.2, >1.2):",
      signif(tapply(st$er, cut(st$x_soil, c(-Inf, 0.5, 0.8, 1, 1.2, Inf)), median), 3), "\n")
  cat("step, days: 10/50/90/99% and max:",
      signif(quantile(365 * st$h, c(0.1, 0.5, 0.9, 0.99, 1)), 3), "\n")
  ak <- sort(AK)
  gap <- vapply(st$time, function(t) {
    i <- findInterval(t - 1e-12, ak)
    if (i < 1 || i >= length(ak)) NA else 365 * (ak[i + 1] - ak[i])
  }, 0)
  dry <- !is.na(gap) & gap > 1 + 1e-6
  cat(sprintf("steps in multi-day legs %s, median %.2f d; in daily legs median %.2f d\n",
              pct(dry), 365 * median(st$h[dry]), 365 * median(st$h[!dry])))
  cat(sprintf("members held, mean %.1f\n", mean(st$M)))
  out$rows <- rows
  out$st <- st
}
if (nzchar(Sys.getenv("OUT"))) saveRDS(out, Sys.getenv("OUT"))
