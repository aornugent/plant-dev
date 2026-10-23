# The field cut in plant on odelia 0.9.0: one recording of a resident, swept
# with the field kept (F_theta) and with it fixed (g), against plant's invader
# gradient at theta' = theta. Needs plant and odelia on their field-cut-066
# branches.
#
#   R_LIBS_PILOT=/path/to/lib  odelia and phylloptim installed there
#   PLANT_DIR=/path/to/plant   built with `make` first (-O2)
#   RECORD=constant|long-drought
#     constant      TF24 at lma 0.0825, rainfall 1, a node every 0.25 years
#     long-drought  harness/long_drought.R's stand: lma 0.32, its record,
#                   ode_tol 1e-3, a stop at each active knot; NODES nodes
#   LIFETIME=<years>           default 10 (constant), 40 (long-drought)
#   NODES=<n>                  default 55 (long-drought only)
#   REPS=<n>                   timing repeats, best taken; default 5
lib <- Sys.getenv("R_LIBS_PILOT")
if (nzchar(lib)) .libPaths(c(lib, .libPaths()))
RECORD <- Sys.getenv("RECORD", "constant")
if (!nzchar(Sys.getenv("LIFETIME"))) {
  Sys.setenv(LIFETIME = if (RECORD == "constant") "10" else "40")
}
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) ".")
# Loads odelia with library() and plant through load_all, and defines the
# long-drought record whether it is used or not.
source(file.path(here, "..", "..", "harness", "long_drought.R"), chdir = TRUE)
REPS <- as.integer(Sys.getenv("REPS", "5"))
metric <- "1.net_reproduction_ratio"
offspring <- "1.offspring_production"

resident <- function() {
  if (RECORD == "constant") {
    p <- scm_base_parameters("TF24")
    p$patch_type <- "fixed"
    p$max_patch_lifetime <- LIFETIME
    p <- add_strategies(p, trait_matrix(0.0825, "lma"),
                        hyperpar = TF24_hyperpar, birth_rate = 1)
    p$node_schedule_times <-
      list(node_schedule_times_periodic(0, LIFETIME, 0.25))
    env <- Environment("TF24")
    env$extrinsic_drivers_set_constant("rainfall", 1)
    ctrl <- Control(node_density_in_birth_date = TRUE, ode_step_size_max = 0.05)
    ev <- NULL
  } else {
    times <- uniform_times(as.integer(Sys.getenv("NODES", "55")))
    p <- stand_at(times)
    env <- mkenv(RECORD)
    ctrl <- control()
    ctrl$ode_tol_rel <- JTOL
    ctrl$ode_tol_abs <- JTOL
    ctrl$node_density_in_birth_date <- TRUE
    ev <- events(events_default(p), pulse_rows(sort(unique(AK))))
  }
  list(p = p, env = env, ctrl = ctrl, ev = ev)
}

r <- resident()
t_run <- system.time(
  scm <- run_scm(r$p, r$env, r$ctrl, keep_states = TRUE, events = r$ev)
)[["elapsed"]]
b <- census_backend(scm)
traits <- b$trait_names(scm)
fit <- stand_fitness(scm)

# Each call records every step once and sweeps one adjoint per row; with the
# field fixed, the last row is swept with it fixed.
sweep <- function(rows, fixed) {
  fix_field_in_last_sweep(fixed)
  on.exit(fix_field_in_last_sweep(FALSE))
  t <- system.time(s <- b$trait_gradient(scm, rows))[["elapsed"]]
  stopifnot(!any(vapply(s$refusal, Negate(is.null), TRUE)))
  list(t = t, g = lapply(s$gradient, setNames, traits))
}
best <- function(f) {
  runs <- replicate(REPS, f(), simplify = FALSE)
  runs[[which.min(vapply(runs, `[[`, 0, "t"))]]
}
load_now <- function() scan("/proc/loadavg", what = "", quiet = TRUE)[1:3]

load0 <- load_now()
kept <- best(function() sweep(metric, FALSE))
kept2 <- best(function() sweep(c(metric, metric), FALSE))
kept_cut <- best(function() sweep(c(metric, metric), TRUE))
cut_only <- best(function() sweep(metric, TRUE))
F_theta <- kept$g[[1]]
g_cut <- kept_cut$g[[2]]
stopifnot(identical(F_theta, kept_cut$g[[1]]),
          identical(F_theta, kept2$g[[2]]),
          identical(g_cut, cut_only$g[[1]]))
# Total offspring, with the field fixed: its birth-rate elasticity is 1.
g_off <- sweep(offspring, TRUE)$g[[1]]

# The invader at the resident's own traits, in the recorded field. The first
# call builds the field rows the later ones share.
invade <- function() {
  t <- system.time({
    scm$run_mutant(scm$parameters)
    s <- b$trait_gradient(scm, metric)
  })[["elapsed"]]
  list(t = t, g = setNames(s$gradient[[1]], traits),
       value = stand_fitness(scm)[[metric]])
}
first_inv <- invade()
inv <- best(invade)
load1 <- load_now()
g_inv <- inv$g

rel <- function(a, b) abs(a - b) / pmax(abs(a), abs(b), 1e-300)
tab <- data.frame(F_theta = F_theta, g_cut = g_cut, g_invader = g_inv,
                  rel = rel(g_cut, g_inv))
tab <- tab[order(-abs(tab$g_invader)), ]

cat(sprintf("TF24 %s, lifetime %g, %d steps: R0 resident %.15g, invader %.15g (rel %.2e)\n",
            RECORD, LIFETIME, length(scm$ode_times), fit[[metric]], inv$value,
            rel(fit[[metric]], inv$value)))
cat(sprintf("columns %d; nonzero invader %d\n", length(traits), sum(g_inv != 0)))
print(signif(head(tab, 15), 6))
nz <- abs(tab$g_invader) > 1e-12 * max(abs(tab$g_invader))
cat(sprintf("max rel(g_cut, g_invader) over %d nonzero columns: %.3e\n",
            sum(nz), max(tab$rel[nz])))
cat(sprintf("max |g_cut| over the %d columns where the invader is below that: %.3e\n",
            sum(!nz), if (any(!nz)) max(abs(tab$g_cut[!nz])) else 0))
br <- "1.birth_rate"
bval <- 1  # every species here is born at rate 1, so d/d ln b = d/db
cat(sprintf(paste0("birth rate, field fixed: dR0/dln b = %.6e (invader %.6e, kept %.6e); ",
                   "dln(offspring)/dln b = %.15g\n"),
            bval * g_cut[[br]], bval * g_inv[[br]], bval * F_theta[[br]],
            bval * g_off[[br]] / fit[[offspring]]))
cat(sprintf(paste0("seconds, best of %d: run %.2f; kept %.3f; 2 kept %.3f; ",
                   "kept + cut %.3f; cut alone %.3f; invader run + sweep %.3f ",
                   "(first %.3f)\n"),
            REPS, t_run, kept$t, kept2$t, kept_cut$t, cut_only$t, inv$t,
            first_inv$t))
cat(sprintf(paste0("ratios to kept: kept + cut %.2f; cut alone %.2f; ",
                   "invader %.2f; added cut sweep / added kept sweep %.2f\n"),
            kept_cut$t / kept$t, cut_only$t / kept$t, inv$t / kept$t,
            (kept_cut$t - kept$t) / (kept2$t - kept$t)))
cat(sprintf("load average before %s, after %s\n", paste(load0, collapse = " "),
            paste(load1, collapse = " ")))
