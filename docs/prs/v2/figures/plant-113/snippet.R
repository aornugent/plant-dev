source("harness/long_drought.R")   # the synthetic record, its knots AK, stand_at()
times <- uniform_times(108)
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-3, ode_tol_abs = 1e-3)
p <- stand_at(times)                # one TF24 species at lma 0.32
scm <- run_scm(p, mkenv(), ctrl,
               events = events(events_default(p), pulse_rows(AK)))
sum(scm$offspring_production)
scm$run_mutant(stand_at(times, "lma", 2))   # an invader on the resident's steps
sum(scm$offspring_production)
