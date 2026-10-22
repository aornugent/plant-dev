# The field cut in plant: one recording of a resident, swept with the field
# kept (F_theta) and with it held (g), against plant's invader gradient at
# theta' = theta. Needs plant and odelia on their field-cut-pilot branches.
#
#   R_LIBS_PILOT=/path/to/lib  odelia (and phylloptim) installed there
#   PLANT_DIR=/path/to/plant   built with `make` first (-O2)
#   MODEL=TF24|FF16            default TF24
#   LIFETIME=<years>           default 2 (TF24), 8 (FF16)
lib <- Sys.getenv("R_LIBS_PILOT")
if (nzchar(lib)) .libPaths(c(lib, .libPaths()))
suppressMessages(library(odelia))
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) ".")
suppressMessages(pkgload::load_all(
  Sys.getenv("PLANT_DIR", file.path(here, "..", "..", "plant")), quiet = TRUE))

MODEL <- Sys.getenv("MODEL", "TF24")
LIFETIME <- as.numeric(Sys.getenv("LIFETIME", if (MODEL == "TF24") "2" else "8"))
metric <- "1.net_reproduction_ratio"

resident <- function() {
  if (MODEL == "TF24") {
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
  } else {
    p <- scm_base_parameters("FF16")
    p$max_patch_lifetime <- LIFETIME
    p <- add_strategies(p, trait_matrix(c(0.0825, 3), c("lma", "hmat")),
                        birth_rate = list(2))
    env <- NULL
    ctrl <- Control(node_density_in_birth_date = TRUE,
                    offspring_production_tol = 1e-12)
  }
  list(p = p, env = env, ctrl = ctrl)
}

r <- resident()
t_run <- system.time(
  scm <- run_scm(r$p, r$env, r$ctrl, record_trajectory = TRUE))[["elapsed"]]
b <- census_backend(scm)
traits <- b$trait_names(scm)
R0 <- stand_fitness(scm)[[metric]]

sweep <- function(rows, held) {
  field_cut_hold(held)
  on.exit(field_cut_hold(FALSE))
  t <- system.time(s <- b$trait_gradient(scm, rows))[["elapsed"]]
  stopifnot(!any(vapply(s$refusal, Negate(is.null), TRUE)))
  list(t = t, g = lapply(s$gradient, setNames, traits))
}
# Each call records every step once and sweeps each row; differences between
# calls price one sweep. Repeated, minimum taken.
best <- function(rows, held, n = 3) {
  runs <- replicate(n, sweep(rows, held), simplify = FALSE)
  runs[[which.min(vapply(runs, `[[`, 0, "t"))]]
}
one   <- best(metric, FALSE)
four  <- best(rep(metric, 4), FALSE)
five  <- best(rep(metric, 5), FALSE)
cut   <- best(rep(metric, 5), TRUE)
F_theta <- cut$g[[1]]
g_cut <- cut$g[[5]]
stopifnot(identical(F_theta, one$g[[1]]), identical(F_theta, cut$g[[4]]))

# The invader at the resident's own traits, in the recorded field.
t_inv <- system.time({
  scm$run_mutant(scm$parameters)
  inv <- stand_gradient(scm, metrics = metric)
})[["elapsed"]]
g_inv <- inv$gradient[metric, traits]

rel <- function(a, b) abs(a - b) / pmax(abs(a), abs(b), 1e-300)
tab <- data.frame(F_theta = F_theta, g_cut = g_cut, g_invader = g_inv,
                  rel = rel(g_cut, g_inv))
tab <- tab[order(-abs(tab$g_invader)), ]

cat(sprintf("%s, lifetime %g: R0 resident %.15g, invader %.15g (rel %.2e)\n",
            MODEL, LIFETIME, R0, inv$value[[metric]],
            rel(R0, inv$value[[metric]])))
cat(sprintf("columns %d; nonzero invader %d\n", length(traits),
            sum(g_inv != 0)))
print(signif(head(tab, 15), 6))
nz <- abs(tab$g_invader) > 1e-12 * max(abs(tab$g_invader))
cat(sprintf("max rel(g_cut, g_invader) over %d nonzero columns: %.3e\n",
            sum(nz), max(tab$rel[nz])))
cat("columns below that threshold, and the birth rate:\n")
print(signif(tab[!nz | rownames(tab) == "1.birth_rate", ], 6))
kept_sweep <- (five$t - one$t) / 4
cat(sprintf(paste0("seconds: run %.2f; recording + 1 kept row %.2f; 4 kept %.2f; ",
                   "5 kept %.2f; 4 kept + cut %.2f; invader replay + sweep %.2f\n"),
            t_run, one$t, four$t, five$t, cut$t, t_inv))
cat(sprintf("kept sweep %.3f s, cut sweep %.3f s: ratio %.2f\n", kept_sweep,
            cut$t - four$t, (cut$t - four$t) / kept_sweep))
