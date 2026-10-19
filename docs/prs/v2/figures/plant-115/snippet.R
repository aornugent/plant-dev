source("harness/long_drought.R")   # the synthetic record, its knots AK, stand_at()
ctrl <- Control(node_density_in_birth_date = TRUE,
                ode_tol_rel = 1e-4, ode_tol_abs = 1e-4)
p <- stand_at(uniform_times(108))
stopped <- run_scm(p, mkenv(), ctrl,      # a zero-depth pulse at each of 2931 knots
                   events = events(events_default(p), pulse_rows(AK)))
free <- run_scm(p, mkenv(), ctrl)         # no stops
c(stopped = sum(stopped$offspring_production), free = sum(free$offspring_production))
c(stopped = length(stopped$ode_times), free = length(free$ode_times)) - 1
