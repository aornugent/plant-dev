# The cut's sweep of J under callgrind. The recorded forward runs with
# instrumentation off; two handshakes on sentinel files bracket the sweep, so
# instrumentation covers stand_gradient(scm, metrics = "offspring_production")
# and nothing else. Driven by sp_cg.sh.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile/sp_common.R")
T <- as.numeric(Sys.getenv("T", "5"))
TAG <- Sys.getenv("PROF_TAG", "cg")
CGD <- file.path(SPD, "cg")
cfg <- config(T, 0L)
kinds <- plant:::census_operating_point_names_tf24()
cat(lib_tag(), "\n")
scm <- build_scm(cfg$times, cfg$lifetime, stops = cfg$stops)
scm$record_trajectory <- TRUE
scm$run()
att <- scm$ode_step_attempts
rows <- member_steps(scm$ode_times, cfg$times)
cat(sprintf("cut: lifetime %g, %d nodes, %d stops; J %.9g accepted %d attempts %d rows %.0f leaf solves %.0f\n",
            T, length(cfg$times), length(cfg$stops), sum(scm$offspring_production),
            att[["accepted"]], sum(att), rows,
            sum(plant:::census_operating_point_counts_tf24(scm)[[1]])))
plant:::census_clear_diagnostics_tf24(scm)
wait_for <- function(f) { while (!file.exists(f)) Sys.sleep(0.2); invisible(file.remove(f)) }
cat(sprintf("pid %d\n", Sys.getpid()))
cat("READY\n")
wait_for(file.path(CGD, paste0(TAG, "_go")))
g <- stand_gradient(scm, metrics = "offspring_production")
cat("SWEEPEND\n")
wait_for(file.path(CGD, paste0(TAG, "_stop")))
leaf_sw <- setNames(plant:::census_operating_point_counts_tf24(scm)[[1]], kinds)
cat(sprintf("sweep: leaf solves %.0f (%s); refused %s; dJ/dlma column %.9g\n",
            sum(leaf_sw), paste(names(leaf_sw), leaf_sw, sep = "=", collapse = ","),
            paste(stand_gradient_refused(g), collapse = ","),
            g$gradient["offspring_production", "1.lma"]))
# The recording's rows: accepted steps, and insertions (introductions and pulses).
rec <- scm$store_trajectory()
ins <- tryCatch(vapply(rec, function(r) isTRUE(r$insertion), logical(1)),
                error = function(e) NA)
cat(sprintf("recording: %d rows, %s insertions; row fields %s\n", length(rec),
            format(sum(ins)), paste(names(rec[[1]]), collapse = ",")))
saveRDS(list(T = T, times = cfg$times, stops = cfg$stops, attempts = att, rows = rows,
             ode_times = scm$ode_times, rec_rows = length(rec), insertions = sum(ins),
             leaf_sweep = leaf_sw, gradient = g$gradient),
        file.path(SPD, "out", paste0("cg_", TAG, ".rds")))
cat("SPCG DONE\n")
