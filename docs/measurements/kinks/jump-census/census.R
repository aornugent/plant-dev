# One case of the bank replayed pinned on its own saved steps, forward only, on
# the library it ran with; reads J against the saved J and the operating-point and
# clamp tallies of the evaluations the replay walks.
# Usage: Rscript census.R <case>   (e.g. dry, long-drought, wet-adG2)
# Env: OUTDIR (where the per-case rds goes).
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap"
case <- commandArgs(TRUE)[1]
out_dir <- Sys.getenv("OUTDIR")
src <- file.path(A, "runs", sprintf("val_ins75_c_%s.rds", case))
x <- readRDS(src)
st <- x$setting
times_file <- file.path(out_dir, sprintf("times_%s.rds", case))
saveRDS(x$node_times, times_file)

env <- st$env
env[["PIN"]] <- src
env[["COARSE"]] <- ""
do.call(Sys.setenv, as.list(env))
Sys.setenv(REGIME = st$regime, SEED = st$seed, TOL = format(st$tol, digits = 17),
           ATOL = format(st$atol, digits = 17), TIMES = times_file, MODE = "plain",
           FORWARD = "1", OUT = "", INVADERS_REL = "", SOILREC = "", SWEEP0 = "",
           LIFETIME = format(st$lifetime))
stopifnot(Sys.getenv("LIB") == file.path(A, "libS"))
rm(x)
source(file.path(A, "adj_run_nk.R"))
saved <- readRDS(src)$stand

op <- setNames(plant:::census_operating_point_counts_tf24(scm)[[1]],
               plant:::census_operating_point_names_tf24())
cl <- setNames(plant:::census_clamp_counts_tf24(scm)[[1]], plant:::census_clamp_names_tf24())
res <- list(case = case, setting = st, lib = .libPaths()[1],
            plant_path = find.package("plant"),
            J = out$stand$J, J_saved = saved$J,
            J_rel = out$stand$J / saved$J - 1,
            steps = length(out$stand$times) - 1, steps_saved = length(saved$times) - 1,
            times_identical = identical(out$stand$times, saved$times),
            times_maxdiff = if (length(out$stand$times) == length(saved$times))
              max(abs(out$stand$times - saved$times)) else NA,
            attempts = scm$ode_step_attempts,
            operating_points = op, clamps = cl, cpu = out$stand$cpu)
saveRDS(res, file.path(out_dir, sprintf("census_%s.rds", case)))
unlink(times_file)
cat(sprintf("%s: J %.15g saved %.15g rel %.2e; steps %d/%d identical %s\n", case, res$J,
            res$J_saved, res$J_rel, res$steps, res$steps_saved, res$times_identical))
print(op); print(cl); print(res$attempts)
