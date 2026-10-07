# Item 7's pilot: the stand on few introductions at a loose tolerance, with its
# invaders at lma's range ends walked on its recording, read into the window's
# weights by plant's control_window(), and written as run_record.R's WEIGHT table
# (t, weight).
#
#   PLANT_LIB=... [REGIME=long-drought] [NODES=54] [TIMES=t.rds] [TOL=1e-3] \
#     [SHARE=0.1] [R0=0.1] [R_MIN=0.01] OUT=weight.rds Rscript harness/pilot_window.R
#
# The pilot runs at control_tf24(TOL)'s setting, on the birth-date coordinate.
# TIMES reads the introductions from a file in place of NODES; SHARE steps the
# soil alone where the members draw under that share of it.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
regime <- Sys.getenv("REGIME", SCEN)
scen <- sprintf("%s, seed %d", regime, RAIN_SPECS[[regime]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[regime]]
times <- if (nzchar(Sys.getenv("TIMES"))) readRDS(Sys.getenv("TIMES")) else
  uniform_times(as.integer(Sys.getenv("NODES", "54")))
tol <- as.numeric(Sys.getenv("TOL", "1e-3"))
out_file <- Sys.getenv("OUT")

p <- stand_at(times)
ct <- control_tf24(tol, Control(node_density_in_birth_date = TRUE))
if (nzchar(Sys.getenv("SHARE"))) ct$ode_soil_alone_share <- as.numeric(Sys.getenv("SHARE"))
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
t0 <- proc.time()[["elapsed"]]
pilot <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
rows <- sum(vapply(head(pilot$ode_times, -1), function(t) sum(times <= t), 0))
ctrl <- control_window(pilot, list(stand_at(times, "lma", 0.5), stand_at(times, "lma", 2)),
                       base = ct, R0 = as.numeric(Sys.getenv("R0", "0.1")),
                       r_min = as.numeric(Sys.getenv("R_MIN", "0.01")))
w <- data.frame(t = ctrl$ode_weight_times, weight = ctrl$ode_weight_factors)
attr(w, "pilot") <- list(regime = regime, nodes = length(times), tol = tol, rows = rows,
                         secs = proc.time()[["elapsed"]] - t0,
                         lib = Sys.getenv("PLANT_LIB"))
if (nzchar(out_file)) saveRDS(w, out_file)
cat(sprintf("%s pilot: %d nodes at %g, %.0f rows, %.0f s; factors %.3g to %.3g over %d times\n",
            regime, length(times), tol, rows, attr(w, "pilot")$secs, min(w$weight),
            max(w$weight), nrow(w)))
