# Second derivatives of ln J on one frozen step grid. The reverse-mode gradient is
# taken at lma * exp(U), lma alone and not through the hyperparameterisation, on
# the long-drought stand of the record SEED draws:
# - a resident pinned to the steps of the run at theta0 (PROGRAM);
# - or an invader walked through that run's recorded field (ROLE=invader).
# Differencing two such gradients over a small U gives the slope between the
# gradient's jumps; over a large U, the chord across them.
#
#   PLANT_LIB=... [SEED=31] [TOL=1e-4] [U=...] OUT=base.rds Rscript harness/curvature.R
#   PLANT_LIB=... PROGRAM=base.rds U=1e-4 [ROLE=invader] OUT=... Rscript harness/curvature.R
#
# The first form runs adaptively, at theta0 unless U is given, and writes its step
# program with its gradient. The absolute tolerance is tied to 1e-4 of the
# relative one.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
seed <- as.integer(Sys.getenv("SEED", "31"))
tol <- as.numeric(Sys.getenv("TOL", "1e-4"))
u <- as.numeric(Sys.getenv("U", "0"))
role <- Sys.getenv("ROLE", "resident")
program <- Sys.getenv("PROGRAM")
out_file <- Sys.getenv("OUT")

scen <- sprintf("%s, seed %d", SCEN, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[SCEN]], list(seed = seed))

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(uniform_times(108))
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- 1e-4 * tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))

at_u <- function(q) {
  strategies <- q$strategies
  strategies[[1]]$pars$lma <- strategies[[1]]$pars$lma * exp(u)
  q$strategies <- strategies
  q
}
clock <- function() proc.time()[["elapsed"]]
t0 <- clock()

# The resident's J is a sum over the run; the gradient's columns are per unit of
# each parameter, and the elasticities use the parameters the run was given.
summary_of <- function(scm, q) {
  g <- stand_gradient(scm, metrics = "offspring_production")
  pars <- q$strategies[[1]]$pars
  grad <- g$gradient["offspring_production", ]
  theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
  J <- sum(scm$offspring_production)
  list(J = J, gradient = grad, theta = theta,
       elasticity = ifelse(theta == 0, 1, theta) * grad / J,
       refused = !is.null(g$refusal[["offspring_production"]]))
}

if (!nzchar(program)) {
  q <- at_u(p)
  scm <- run_scm(q, mkenv(scen), ct, events = ev)
  out <- c(list(role = "base", seed = seed, u = u, tol = tol, times = scm$ode_times,
                sizes = scm$ode_step_sizes, attempts = scm$ode_step_attempts),
           summary_of(scm, q))
} else if (role == "resident") {
  base <- readRDS(program)
  stopifnot(base$seed == seed)
  q <- at_u(p)
  q$ode_times <- base$times
  q$ode_step_sizes <- base$sizes
  scm <- run_scm(q, mkenv(scen), ct, events = ev)
  stopifnot(identical(scm$ode_times, base$times))
  out <- c(list(role = role, seed = seed, u = u, tol = tol), summary_of(scm, q))
} else {
  scm <- run_scm(p, mkenv(scen), ct, events = ev)
  stopifnot(identical(scm$ode_times, readRDS(program)$times))
  q <- at_u(p)
  scm$run_mutant(q)
  out <- c(list(role = role, seed = seed, u = u, tol = tol), summary_of(scm, q))
}
out$secs <- clock() - t0
cat(sprintf("seed %d, %s u %+.0e: J %.12f, lma elasticity %.9f, %.0f s\n", seed, out$role,
            u, out$J, out$elasticity[["1.lma"]], out$secs))
if (nzchar(out_file)) saveRDS(out, out_file)
