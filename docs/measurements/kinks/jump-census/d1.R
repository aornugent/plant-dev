# D1 of prereg2.md: one case of the bank replayed pinned on its own saved steps,
# forward only, on the patched library; reads J against the saved J, the census
# tallies, and each recorded evaluation's leaf solves (census_solved_tf24).
# Usage: Rscript d1.R <case> [<pin rds>] [<tag>]
# Env: OUTDIR, LIBJC2 (the patched library), TRAIT_REL_OVERRIDE (optional).
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap"
a <- commandArgs(TRUE)
case <- a[1]
out_dir <- Sys.getenv("OUTDIR")
src <- file.path(A, "runs", sprintf("val_ins75_c_%s.rds", case))
pin <- if (length(a) > 1 && nzchar(a[2])) a[2] else src
tag <- if (length(a) > 2) a[3] else case
x <- readRDS(src)
st <- x$setting
times_file <- file.path(out_dir, sprintf("times_%s.rds", tag))
saveRDS(x$node_times, times_file)

env <- st$env
env[["PIN"]] <- pin
env[["COARSE"]] <- ""
env[["LIB"]] <- Sys.getenv("LIBJC2")
do.call(Sys.setenv, as.list(env))
Sys.setenv(REGIME = st$regime, SEED = st$seed, TOL = format(st$tol, digits = 17),
           ATOL = format(st$atol, digits = 17), TIMES = times_file, MODE = "plain",
           FORWARD = "1", OUT = "", INVADERS_REL = "", SOILREC = "", SWEEP0 = "",
           LIFETIME = format(st$lifetime))
rm(x)
source(file.path(A, "adj_run_nk.R"))
stopifnot(normalizePath(dirname(find.package("plant"))) == normalizePath(Sys.getenv("LIBJC2")))
saved <- readRDS(src)$stand

op <- setNames(plant:::census_operating_point_counts_tf24(scm)[[1]],
               plant:::census_operating_point_names_tf24())
cl <- setNames(plant:::census_clamp_counts_tf24(scm)[[1]], plant:::census_clamp_names_tf24())
sol <- lapply(plant:::census_solved_tf24(scm), as.data.frame)
unstored <- matrix(plant:::census_unstored_tf24(scm), ncol = 2,
                   dimnames = list(plant:::census_operating_point_names_tf24(), c("other", "search")))
res <- list(case = case, tag = tag, pin = pin, setting = st, plant_path = find.package("plant"),
            J = out$stand$J, J_saved = saved$J, J_rel = out$stand$J / saved$J - 1,
            steps = length(out$stand$times) - 1,
            times_identical = identical(out$stand$times, readRDS(pin)$stand$times),
            attempts = scm$ode_step_attempts, node_times = times,
            operating_points = op, clamps = cl, solved = sol, unstored = unstored, cpu = out$stand$cpu)
saveRDS(res, file.path(out_dir, sprintf("d1_%s.rds", tag)))
unlink(times_file)
cat(sprintf("%s: J %.15g saved %.15g rel %.2e; steps %d identical %s\n", tag, res$J,
            res$J_saved, res$J_rel, res$steps, res$times_identical))
print(op[op > 0]); print(cl[cl > 0])
print(unstored[rowSums(unstored) > 0, ])
cat(sprintf("evals %d, solves listed %d; recorded kinds: k4 %d k5 %d k6 %d; ceiling evals %d\n",
            nrow(sol$evals), nrow(sol$solves), sum(sol$evals$k4), sum(sol$evals$k5),
            sum(sol$evals$k6), sum(sol$evals$ceiling != 0)))
