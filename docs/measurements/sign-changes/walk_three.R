# G5 of the seventeenth extension (prereg.txt): the stand on the pinned split
# program, then its own strategy walked alone and as the middle of three
# invaders at lma x 0.95, 1 and 1.05; each walk's offspring production against
# the stand's, to the bit.
#   PLANT_LIB=... PROGRAM=program_split.rds [SPLIT=1] OUT=walk_three.rds \
#     Rscript walk_three.R
local({
  self <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
  source(file.path(dirname(normalizePath(self)), "../../../harness/long_drought.R"))
})
times <- uniform_times(108)
program <- readRDS(Sys.getenv("PROGRAM"))$st
p <- stand_at(times)
p$ode_times <- c(0, program$time)
p$ode_step_sizes <- c(NaN, program$h)
ct <- control()
ct$ode_tol_rel <- 1e-4
ct$ode_tol_abs <- 1e-8
ct$node_density_in_birth_date <- TRUE
ct$ode_split_sign_changes <- Sys.getenv("SPLIT", "1") == "1"
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(SCEN)))))
scm <- run_scm(p, mkenv(SCEN), ct, events = ev, record_trajectory = TRUE)
J <- sum(scm$offspring_production)
splits <- sum(scm$ode_splits)
t0 <- proc.time()[["elapsed"]]
scm$run_mutant(stand_at(times))
alone <- sum(scm$offspring_production)
t_alone <- proc.time()[["elapsed"]] - t0
q <- scm_base_parameters("TF24")
q$max_patch_lifetime <- LIFETIME
q <- add_strategies(q, trait_matrix(LMA0 * c(0.95, 1, 1.05), "lma"),
                    birth_rate = rep(1, 3))
q$node_schedule_times <- rep(list(times), 3)
scm$run_mutant(q)
three <- scm$offspring_production
out <- list(J = J, splits = splits, alone = alone, three = three, walk_secs = t_alone)
if (nzchar(Sys.getenv("OUT"))) saveRDS(out, Sys.getenv("OUT"))
cat(sprintf("stand J %.15g (%d node steps split); walked alone %.15g, identical %s\n",
            J, splits, alone, identical(J, alone)))
cat(sprintf("three: %s; the middle identical %s; the walk alone took %.1f s\n",
            paste(sprintf("%.15g", three), collapse = ", "), identical(J, three[[2]]),
            t_alone))
