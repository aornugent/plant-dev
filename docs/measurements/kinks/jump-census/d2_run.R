# D2 of prereg2.md: one long-wet run pinned on a step program, on the patched
# library, through adj_run_nk.R with the committed run's settings.
# Usage: Rscript d2_run.R <tag> <pin rds> <TRAIT_REL or ""> <forward 1|0>
# Env: OUTDIR, LIBJC2. Writes <OUTDIR>/d2_<tag>.rds (adj_run_nk.R's `out`, with the
# step program dropped to keep it small, plus the census tallies).
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap"
a <- commandArgs(TRUE)
tag <- a[1]; pin <- a[2]; trait_rel <- a[3]; forward <- a[4]
out_dir <- Sys.getenv("OUTDIR")
src <- file.path(A, "runs", "val_ins75_c_long-wet.rds")
x <- readRDS(src)
st <- x$setting
stopifnot(st$env[["TRAIT_REL"]] == "")
times_file <- file.path(out_dir, sprintf("times_%s.rds", tag))
saveRDS(x$node_times, times_file)
env <- st$env
env[["PIN"]] <- pin
env[["COARSE"]] <- ""
env[["TRAIT_REL"]] <- trait_rel
env[["LIB"]] <- Sys.getenv("LIBJC2")
do.call(Sys.setenv, as.list(env))
Sys.setenv(REGIME = st$regime, SEED = st$seed, TOL = format(st$tol, digits = 17),
           ATOL = format(st$atol, digits = 17), TIMES = times_file, MODE = "plain",
           FORWARD = forward, OUT = "", INVADERS_REL = "", SOILREC = "", SWEEP0 = "",
           LIFETIME = format(st$lifetime))
rm(x)
source(file.path(A, "adj_run_nk.R"))
stopifnot(normalizePath(dirname(find.package("plant"))) == normalizePath(Sys.getenv("LIBJC2")))
pt <- readRDS(pin)$stand$times
res <- list(tag = tag, pin = pin, trait_rel = trait_rel, J = out$stand$J,
            lnJ = log(out$stand$J), steps = length(out$stand$times) - 1,
            times_identical = identical(out$stand$times, pt),
            attempts = range(scm$ode_step_attempts),
            gradient = out$stand$gradient, elasticity = out$stand$elasticity,
            refusal = out$refusal, cpu = out$stand$cpu, sweep_cpu = out$sweep_cpu,
            operating_points = setNames(plant:::census_operating_point_counts_tf24(scm)[[1]],
                                        plant:::census_operating_point_names_tf24()))
if (Sys.getenv("SOLVED") == "1") res$solved <- plant:::census_solved_tf24(scm)
saveRDS(res, file.path(out_dir, sprintf("d2_%s.rds", tag)))
unlink(times_file)
cat(sprintf("%s [%s]: J %.15g lnJ %.15g steps %d identical-to-pin %s attempts %s cpu %.0f sweep %s\n",
            tag, trait_rel, res$J, res$lnJ, res$steps, res$times_identical,
            paste(res$attempts, collapse = "-"), res$cpu, format(res$sweep_cpu)))
