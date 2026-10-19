# One forward of the long-drought TF24 stand at n uniform introductions, the
# rainfall's knots as stops (harness/long_drought.R's run_J), reporting whether
# the final heights are out of order.
# Usage: PLANT_LIB=... Rscript forward.R <label> <n> <tol>
args <- commandArgs(TRUE)
label <- args[[1]]; n <- as.integer(args[[2]]); tol <- as.numeric(args[[3]])
source("/home/user/plant-dev/harness/long_drought.R")
times <- uniform_times(n)
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(AK))))
t0 <- proc.time()
scm <- run_scm(p, mkenv(), ct, events = ev)
el <- proc.time() - t0
h <- scm$patch$species[[1]]$heights
cat(sprintf(paste("%s n=%d tol=%g J=%.17g lnJ=%.17g steps=%d elapsed=%.1f",
                  "cpu=%.1f end_pairs_out_of_order=%d max_gap_mm=%.3f\n"),
            label, n, tol, sum(scm$offspring_production),
            log(sum(scm$offspring_production)), length(scm$ode_times),
            el[["elapsed"]], el[["user.self"]] + el[["sys.self"]],
            sum(diff(h) > 0), 1000 * max(c(0, diff(h)))))
