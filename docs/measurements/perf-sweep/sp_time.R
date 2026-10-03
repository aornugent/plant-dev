# CPU of a plain forward, a recorded forward and the sweep of J
# (stand_gradient(scm, metrics = "offspring_production")), with the counts that
# turn them into per-row costs. A row is one member on one accepted step.
#   PLANT_LIB=... [PLANT_PROBE_SPREAD=8] [T=5] [NODES=108] [REPS=1] [PLAIN=1] \
#     OUT=x.rds Rscript sp_time.R
# T > 0 is the cut (uniform-429 times before T, lifetime T); T = 0 is the full
# 40-year run on uniform NODES.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile/sp_common.R")
T <- as.numeric(Sys.getenv("T", "5"))
NODES <- as.integer(Sys.getenv("NODES", "108"))
REPS <- as.integer(Sys.getenv("REPS", "1"))
PLAIN <- Sys.getenv("PLAIN", "1") == "1"
OUT <- Sys.getenv("OUT")
cfg <- config(T, NODES)
kinds <- plant:::census_operating_point_names_tf24()
cat(lib_tag(), "\n")
cat(sprintf("config: T %g, %d nodes, %d stops, tol %g\n", cfg$lifetime,
            length(cfg$times), length(cfg$stops), TOL))

res <- list()
for (r in seq_len(REPS)) {
  out <- list()
  if (PLAIN) {
    scm0 <- build_scm(cfg$times, cfg$lifetime, stops = cfg$stops)
    f0 <- phase(function() scm0$run())
    out$plain <- list(cpu = f0$cpu, peak = f0$peak, J = sum(scm0$offspring_production),
                      steps = length(scm0$ode_step_sizes), attempts = scm0$ode_step_attempts,
                      leaf = setNames(plant:::census_operating_point_counts_tf24(scm0)[[1]], kinds))
    cat(sprintf("rep %d plain forward: user %.2f s  J %.9g  accepted %d  attempts %d  leaf solves %.0f  peak %.0f MB\n",
                r, f0$cpu[["user"]], out$plain$J, out$plain$attempts[["accepted"]],
                sum(out$plain$attempts), sum(out$plain$leaf), f0$peak / 1024))
    rm(scm0); gc()
  }
  scm <- build_scm(cfg$times, cfg$lifetime, stops = cfg$stops)
  scm$record_trajectory <- TRUE
  plant:::census_clear_diagnostics_tf24(scm)
  f1 <- phase(function() scm$run())
  att <- scm$ode_step_attempts
  rows <- member_steps(scm$ode_times, cfg$times)
  leaf_fwd <- setNames(plant:::census_operating_point_counts_tf24(scm)[[1]], kinds)
  out$recorded <- list(cpu = f1$cpu, rss0 = f1$rss0, rss1 = f1$rss1, peak = f1$peak,
                       J = sum(scm$offspring_production), steps = length(scm$ode_step_sizes),
                       attempts = att, rows = rows, leaf = leaf_fwd,
                       ode_times = scm$ode_times)
  cat(sprintf("rep %d recorded forward: user %.2f s  J %.9g  accepted %d  attempts %d  rows %.0f  leaf solves %.0f  rss %.0f -> %.0f MB\n",
              r, f1$cpu[["user"]], out$recorded$J, att[["accepted"]], sum(att), rows,
              sum(leaf_fwd), f1$rss0 / 1024, f1$rss1 / 1024))
  plant:::census_clear_diagnostics_tf24(scm)
  f2 <- phase(function() stand_gradient(scm, metrics = "offspring_production"))
  leaf_sw <- setNames(plant:::census_operating_point_counts_tf24(scm)[[1]], kinds)
  g <- f2$value$gradient["offspring_production", ]
  out$sweep <- list(cpu = f2$cpu, rss0 = f2$rss0, rss1 = f2$rss1, peak = f2$peak,
                    leaf = leaf_sw, gradient = g,
                    refused = stand_gradient_refused(f2$value))
  cat(sprintf("rep %d sweep: user %.2f s  rss %.0f -> %.0f MB, peak %.0f MB  leaf solves in sweep %.0f  refused %s  dJ/dlma column %.6g\n",
              r, f2$cpu[["user"]], f2$rss0 / 1024, f2$rss1 / 1024, f2$peak / 1024,
              sum(leaf_sw), paste(out$sweep$refused, collapse = ","), g[["1.lma"]]))
  cat(sprintf("rep %d per row: recorded forward %.2f us, sweep %.2f us; sweep / recorded forward %.3f%s\n",
              r, 1e6 * f1$cpu[["user"]] / rows, 1e6 * f2$cpu[["user"]] / rows,
              f2$cpu[["user"]] / f1$cpu[["user"]],
              if (PLAIN) sprintf(", sweep / plain forward %.3f", f2$cpu[["user"]] / out$plain$cpu[["user"]]) else ""))
  # One rate evaluation's transpose at the final state, repeated: under the
  # tapestats shim each is one recording, so the two builds compare at one state.
  out$final_eval <- tryCatch({
    pt <- scm$patch
    lam <- rep(1, length(pt$ode_state))
    c0 <- cpu_now()
    for (i in 1:20) ra <- plant:::ladder_rhs_adjoint_tf24(pt, lam)
    c1 <- cpu_now()
    fe <- list(cpu20 = c1 - c0, nodes = pt$species[[1]]$size, time = pt$time,
               recording = ra$block_recording_size, refused = ra$refused)
    cat(sprintf("rep %d final-state rate transpose: %d nodes at t %.3f, %.3f ms each (cpu), recording %s bytes\n",
                r, fe$nodes, fe$time, 1e3 * (c1 - c0)[["user"]] / 20, format(fe$recording)))
    fe
  }, error = function(e) { cat("final-state probe failed:", conditionMessage(e), "\n"); NULL })
  out$rec_rows <- tryCatch({
    rec <- scm$store_trajectory()
    # The spread field's prefix form needs the nodes tallest first and the
    # newborn no taller than the youngest node (field_splits' `ordered`); the
    # lumped form needs the first only. Read at each recorded state.
    h0 <- scm$patch$species[[1]]$new_node$height
    per <- length(scm$patch$species[[1]]$new_node$ode_names)
    env_w <- length(scm$patch$ode_state) - length(scm$patch$species[[1]]$ode_state)
    ord <- t(vapply(rec, function(x) {
      n <- (length(x$state) - env_w) / per
      if (n < 1) return(c(n, NA, NA, NA))
      h <- x$state[per * (seq_len(n) - 1) + 1]
      c(n, all(diff(h) <= 0), h0 <= h[n], h[n])
    }, numeric(4)))
    data.frame(time = vapply(rec, function(x) x$time, 0),
               width = vapply(rec, function(x) length(x$state), 0L),
               insertion = vapply(rec, function(x) isTRUE(x$introduction), logical(1)),
               nodes = ord[, 1], decreasing = ord[, 2] == 1, newborn_below = ord[, 3] == 1,
               h_last = ord[, 4], h0 = h0)
  }, error = function(e) { cat("rec_rows failed:", conditionMessage(e), "\n"); NULL })
  if (!is.null(out$rec_rows)) {
    rr <- out$rec_rows[!is.na(out$rec_rows$decreasing), ]
    cat(sprintf("rep %d ordering at %d recorded states: heights decreasing %.4f, newborn below youngest %.4f, both %.4f\n",
                r, nrow(rr), mean(rr$decreasing), mean(rr$newborn_below),
                mean(rr$decreasing & rr$newborn_below)))
  }
  res[[r]] <- out
  rm(scm); gc()
}
if (nzchar(OUT)) saveRDS(list(config = cfg[c("lifetime", "times", "stops")], tol = TOL,
                              lib = Sys.getenv("PLANT_LIB"),
                              spread = Sys.getenv("PLANT_PROBE_SPREAD"), reps = res), OUT)
cat("SPTIME DONE\n")
