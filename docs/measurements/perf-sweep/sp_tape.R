# A recorded forward and the sweep of J, run under the tapestats.so shim, plus
# the recording's rows (time, width, insertion) so each tape recording can be
# matched to the row it transposes. Native timing; one repetition.
#   PLANT_LIB=... [PLANT_PROBE_SPREAD=8] [T=5] [NODES=108] OUT=x.rds \
#   SP_ODELIA_SO=... SP_TAPESTATS=x.tsv LD_PRELOAD=.../tapestats.so Rscript sp_tape.R
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile/sp_common.R")
T <- as.numeric(Sys.getenv("T", "5"))
NODES <- as.integer(Sys.getenv("NODES", "108"))
OUT <- Sys.getenv("OUT")
cfg <- config(T, NODES)
cat(lib_tag(), "\n")
cat(sprintf("config: T %g, %d nodes, %d stops, tol %g; tapestats %s\n", cfg$lifetime,
            length(cfg$times), length(cfg$stops), TOL, Sys.getenv("SP_TAPESTATS")))
scm <- build_scm(cfg$times, cfg$lifetime, stops = cfg$stops)
scm$record_trajectory <- TRUE
f1 <- phase(function() scm$run())
att <- scm$ode_step_attempts
rows <- member_steps(scm$ode_times, cfg$times)
cat(sprintf("recorded forward: user %.2f s  J %.9g  accepted %d  attempts %d  rows %.0f\n",
            f1$cpu[["user"]], sum(scm$offspring_production), att[["accepted"]], sum(att), rows))
f2 <- phase(function() stand_gradient(scm, metrics = "offspring_production"))
cat(sprintf("sweep: user %.2f s  wall %.2f s  peak %.0f MB\n", f2$cpu[["user"]],
            f2$cpu[["wall"]], f2$peak / 1024))
rec <- scm$store_trajectory()
cat("row fields:", paste(names(rec[[1]]), collapse = ","), "\n")
rt <- data.frame(time = vapply(rec, function(r) r$time, 0),
                 width = vapply(rec, function(r) length(r$state), 0L),
                 insertion = vapply(rec, function(r) isTRUE(r$introduction), logical(1)),
                 step_size = vapply(rec, function(r) if (is.null(r$step_size)) NA_real_ else r$step_size, 0))
cat(sprintf("recording: %d rows, %d insertions, widths %d..%d\n", nrow(rt), sum(rt$insertion),
            min(rt$width), max(rt$width)))
if (nzchar(OUT)) saveRDS(list(config = cfg[c("lifetime", "times", "stops")], tol = TOL,
                              recorded = f1[c("cpu", "peak")], sweep = f2[c("cpu", "peak")],
                              attempts = att, rows = rows, ode_times = scm$ode_times,
                              rec_rows = rt), OUT)
cat("SPTAPE DONE\n")
