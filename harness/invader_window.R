# The share of J still to be earned after each time, R(t), for the stand and for
# invaders on its recorded field. Each node's survival-weighted offspring is read
# at sample times 0.05 apart off the states a run keeps: the stand's, then each
# invader's walk of the stand's recording, which keeps the invader's states as the
# stand's run kept its own. An invasion costs one walk and no extra run.
#
# INVADERS lists each invader as trait=factor, comma-separated, its traits through
# TF24's hyperparameterisation at that multiple of the stand's; "lma=1" is the
# stand's own traits, whose window must be the stand's. STAND moves the stand's
# own traits the same way, from the default lma=1. The cost is the stand's
# member-steps, each accepted step's members scaled by attempts over accepted
# steps, as harness/chain_creation.R counts them. PROGRAM takes the stand's steps
# from a harness/ark_prototype.R OUT file, as harness/run_record.R does.
#
#   PLANT_LIB=... TIMES=t.rds [REGIME=long-drought] [TOL=3e-5] [ATOL=1e-4] \
#     [INVADERS="lma=0.5,lma=2"] [STAND=lma=1] [PROGRAM=driver.rds] OUT=x.rds \
#     Rscript harness/invader_window.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
regime <- Sys.getenv("REGIME", SCEN)
times <- readRDS(Sys.getenv("TIMES"))
tol <- as.numeric(Sys.getenv("TOL", "3e-5"))
atol <- as.numeric(Sys.getenv("ATOL", "1e-4"))
invaders <- strsplit(Sys.getenv("INVADERS", ""), ",")[[1]]
scen <- sprintf("%s, seed %d", regime, RAIN_SPECS[[regime]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[regime]]

stand <- strsplit(Sys.getenv("STAND", "lma=1"), "=")[[1]]
p <- stand_at(times, stand[1], as.numeric(stand[2]))
program <- if (nzchar(Sys.getenv("PROGRAM"))) readRDS(Sys.getenv("PROGRAM"))$st
if (!is.null(program)) {
  p$ode_times <- c(0, program$time)
  p$ode_step_sizes <- c(NaN, program$h)
}
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
patches <- Weibull_Disturbance_Regime(LIFETIME)
grid <- seq(0.05, LIFETIME, by = 0.05)

# Each node's survival-weighted offspring at the sample times, off the states the
# last run or walk kept, and R(t) from them.
window <- function(scm) {
  sp <- scm$patch$species[[1]]
  per <- length(sp$ode_state) / sp$size
  k <- which(sp$new_node$ode_names == "offspring_produced_survival_weighted")
  rows <- scm$store_trajectory()
  t <- vapply(rows, `[[`, 0, "time")
  len <- lengths(lapply(rows, `[[`, "state"))
  held <- (len - (tail(len, 1) - per * sp$size)) / per
  at <- vapply(grid, function(g) max(which(t <= g)), 0L)
  o <- sapply(seq_len(sp$size), function(j) vapply(at, function(i)
    if (held[i] >= j) rows[[i]]$state[per * (j - 1) + k] else NA_real_, 0))
  w <- sp$establishment_weights[seq_len(sp$size)]
  nrr <- sp$net_reproduction_ratio_by_node
  d <- w * vapply(sp$node_times, patches$density, 0)
  R <- 1 - apply(o, 1, function(x) sum(d * x, na.rm = TRUE)) / sum(d * nrr)
  list(birth = sp$node_times, w = w, nrr = nrr, offspring = o, R = R,
       J = sum(scm$offspring_production))
}
clock <- function() proc.time()[["elapsed"]]

t0 <- clock()
scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
out <- list(setting = list(regime = regime, tol = tol, atol = atol, nodes = length(times)),
            node_times = times, grid = grid, stand = window(scm))
out$stand$secs <- clock() - t0
out$stand$times <- scm$ode_times
out$stand$attempts <- scm$ode_step_attempts
a <- out$stand$attempts
# A pinned run attempts no step it rejects, and reports none, so its steps are its cost.
per_step <- if (a[["accepted"]] > 0)
  (a[["accepted"]] + a[["rejected_inaccurate"]] + a[["rejected_thrown"]]) / a[["accepted"]] else 1
out$stand$member_steps <- sum(as.numeric(findInterval(out$stand$times, sort(times)))) * per_step
cat(sprintf("%s, %d nodes at %g: J %.8g, %d steps, %.3g member-steps, %.0f s\n", scen,
            length(times), tol, out$stand$J, length(out$stand$times), out$stand$member_steps,
            out$stand$secs))
saveRDS(out, Sys.getenv("OUT"))
for (inv in invaders) {
  kv <- strsplit(inv, "=")[[1]]
  t0 <- clock()
  r <- tryCatch({
    scm$run_mutant(stand_at(times, kv[1], as.numeric(kv[2])))
    window(scm)
  }, error = function(e) list(error = conditionMessage(e)))
  r$secs <- clock() - t0
  out$invaders[[inv]] <- r
  saveRDS(out, Sys.getenv("OUT"))
  cat(sprintf("invader %s: %s, %.0f s\n", inv,
              if (is.null(r$error)) sprintf("J' %.8g", r$J) else paste("raised:", r$error), r$secs))
}
