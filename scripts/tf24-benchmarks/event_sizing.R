# Event sizing (Oracle "E1") across the canonical benchmark bank.
#
# For each hard rainfall sequence, run the real coupled TF24 SCM with the
# adaptive controller step log enabled, then attribute where the controller
# collapses its step. Two event surfaces are known a priori and attributed
# exactly: forcing kinks (rain-event days) and member insertions (per-species
# node-introduction times). The residual small/rejected steps are "unattributed"
# = candidate state-dependent events (leaf-shutdown-boundary / argmax-bound /
# soil clamp) OR genuine fast structure -- the split E3 would resolve.
#
# Outputs a per-scenario summary table and saves the raw step logs.

options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("plant", export_all = TRUE, quiet = TRUE)})

datadir <- "scripts/tf24-benchmarks/data"
outdir  <- "scripts/tf24-benchmarks/results"; dir.create(outdir, showWarnings = FALSE)
bank <- readRDS(file.path(datadir, "_manifest.rds"))
TOL_REL <- 1e-6
DAY <- 1 / 365
ATTR_TOL <- 1 * DAY   # a small step is "at" an event if within 1 day of it

enable  <- get("step_log_enable", asNamespace("odelia"))
reset   <- get("step_log_reset",  asNamespace("odelia"))
getlog  <- get("step_log_get",    asNamespace("odelia"))

run_one <- function(nm) {
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  rain <- b$rain; nd <- length(rain); life <- b$life
  times <- (0:(nd - 1)) / 365
  life_run <- max(times)   # never integrate past the last defined rainfall day
  mkenv <- function() { e <- Environment("TF24")
    e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  lma <- if (nm == "multispecies") c(0.0500, 0.0825, 0.1400, 0.2200) else 0.0825
  mk <- function() { p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- life_run
    add_strategies(p, trait_matrix(lma, "lma"), birth_rate = rep(1, length(lma))) }
  ctrl <- control(ode_method = "rkck", ode_tol_rel = TOL_REL, ode_tol_abs = TOL_REL)

  reset(); enable(TRUE); patch_rhs_calls_reset()
  res <- tryCatch({
    wall <- system.time(s <- run_scm(mk(), mkenv(), ctrl))[["elapsed"]]
    list(ok = TRUE, s = s, wall = wall, rhs = patch_rhs_calls_get())
  }, error = function(e) list(ok = FALSE, msg = conditionMessage(e)))
  log <- getlog(); enable(FALSE)

  # event surfaces
  rain_events <- times[rain > 0]                                  # forcing kinks
  insertions <- if (res$ok) sort(unique(unlist(res$s$node_times))) else numeric(0)

  nearest <- function(t, surf) if (length(surf) == 0) Inf else min(abs(t - surf))
  attribute <- function(tt) {
    if (length(tt) == 0) return(c(rain = NA, insert = NA, unattr = NA))
    dr <- vapply(tt, nearest, 0.0, rain_events)
    di <- vapply(tt, nearest, 0.0, insertions)
    near_rain <- dr <= ATTR_TOL
    near_ins  <- (di <= ATTR_TOL) & !near_rain
    c(rain = mean(near_rain), insert = mean(near_ins),
      unattr = mean(!near_rain & !near_ins))
  }

  acc <- log[log$ok == 1, ]; rej <- log[log$ok == 0, ]
  h <- acc$h
  small_thresh <- if (length(h)) as.numeric(quantile(h, 0.10)) else NA
  small_t <- acc$t[h <= small_thresh]
  a_small <- attribute(small_t)
  a_rej   <- attribute(rej$t)

  data.frame(
    scenario = nm, ok = res$ok, life = life,
    n_accept = nrow(acc), n_reject = nrow(rej),
    reject_frac = if (nrow(acc) + nrow(rej) > 0) nrow(rej) / (nrow(acc) + nrow(rej)) else NA,
    rhs = if (res$ok) res$rhs else NA,
    wall_s = if (res$ok) round(res$wall, 1) else NA,
    median_h = if (length(h)) signif(median(h), 3) else NA,
    min_h = if (length(h)) signif(min(h), 3) else NA,
    min_h_over_T = if (length(h)) signif(min(h) / life_run, 3) else NA,
    small_rain = round(a_small[["rain"]], 3),
    small_insert = round(a_small[["insert"]], 3),
    small_unattr = round(a_small[["unattr"]], 3),
    rej_rain = round(a_rej[["rain"]], 3),
    rej_insert = round(a_rej[["insert"]], 3),
    rej_unattr = round(a_rej[["unattr"]], 3),
    offspring = if (res$ok) signif(sum(res$s$offspring_production), 4) else NA,
    note = if (res$ok) "" else substr(res$msg, 1, 40),
    stringsAsFactors = FALSE)
}

rows <- list()
for (nm in bank) {
  cat(sprintf("[%s] running...\n", nm)); flush.console()
  r <- run_one(nm); rows[[nm]] <- r
  print(r[, c("scenario","ok","n_accept","n_reject","reject_frac","min_h_over_T",
              "small_rain","small_insert","small_unattr","wall_s","note")], row.names = FALSE)
  saveRDS(r, file.path(outdir, paste0(nm, "_summary.rds")))
}
summ <- do.call(rbind, rows)
saveRDS(summ, file.path(outdir, "event_sizing_summary.rds"))
write.csv(summ, file.path(outdir, "event_sizing_summary.csv"), row.names = FALSE)
cat("\n===== EVENT SIZING SUMMARY =====\n"); print(summ, row.names = FALSE)
