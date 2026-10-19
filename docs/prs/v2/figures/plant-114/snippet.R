source("harness/long_drought.R")   # the synthetic record, its knots AK, stand_at()
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-3, ode_tol_abs = 1e-3)
p <- stand_at(uniform_times(108))
scm <- run_scm(p, mkenv(), ctrl,
               events = events(events_default(p), pulse_rows(AK)))
h <- scm$patch$species[[1]]$heights   # oldest cohort first
which(diff(h) > 0)                    # a cohort taller than the one born before it
sprintf("%.17g", sum(scm$offspring_production))
