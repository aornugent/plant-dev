# How far J and its trait gradients move between rainfall records of one
# climate: the long-drought stand (harness/long_drought.R) on the record SEED
# draws, every other entry of the spec kept, drought years and mean included.
# The zero-depth pulses sit at that record's own active knots.
#
# For the stand, and then for an invader with the stand's own traits walked
# through the stand's recorded field, it keeps J and the offspring-production
# gradient over every trait column. Each gradient is also kept as the elasticity
# d ln J / d ln theta, or as d ln J / d theta where the trait's value is zero.
#
#   PLANT_LIB=... SEED=101 [TOL=1e-4] [NODES=108] OUT=s101.rds \
#     Rscript harness/eps_spread.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
seed <- as.integer(Sys.getenv("SEED", "31"))
tol <- as.numeric(Sys.getenv("TOL", "1e-4"))
nodes <- as.integer(Sys.getenv("NODES", "108"))
out_file <- Sys.getenv("OUT")

scen <- sprintf("%s, seed %d", SCEN, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[SCEN]], list(seed = seed))
knots <- active_knots(scen)

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(uniform_times(nodes))
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(knots))))

clock <- function() proc.time()[["elapsed"]]
pars <- p$strategies[[1]]$pars

# J as the run left it, then its gradient, which may repeat the run to keep its
# states. A refused gradient is all NaN, with the reason beside it.
gradient_of <- function(scm) {
  J <- sum(scm$offspring_production)
  t0 <- clock()
  g <- stand_gradient(scm, metrics = "offspring_production")
  grad <- g$gradient["offspring_production", ]
  theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
  list(J = J, value = unname(g$value), theta = theta, gradient = grad,
       elasticity = ifelse(theta == 0, 1, theta) * grad / J,
       refusal = g$refusal[["offspring_production"]], control = g$control,
       secs_sweep = clock() - t0)
}
report <- function(who, x) {
  e <- x$elasticity
  cat(sprintf("%s: J %.9f, ln J %.6f; elasticity lma %.5f, a_dG2 %.5f; %s; run %.0f s, sweep %.0f s\n",
              who, x$J, log(x$J), e[["1.lma"]], e[["1.a_dG2"]],
              if (is.null(x$refusal)) "answered" else paste("refused:", x$refusal$reason),
              x$secs_run, x$secs_sweep))
}

out <- list(seed = seed, tol = tol, nodes = nodes, knots = length(knots))
t0 <- clock()
scm <- run_scm(p, mkenv(scen), ct, events = ev)
secs <- clock() - t0
out$steps <- length(scm$ode_times)
out$attempts <- scm$ode_step_attempts
out$stand <- c(gradient_of(scm), secs_run = secs)
report(sprintf("seed %d, tol %g, %d nodes, %d knots, %d steps; stand", seed, tol,
               nodes, length(knots), out$steps), out$stand)
cat(sprintf("the census's offspring production against the run's: %+.2e\n",
            out$stand$value / out$stand$J - 1))
if (nzchar(out_file)) saveRDS(out, out_file)

t0 <- clock()
scm$run_mutant(p)
secs <- clock() - t0
out$invader <- c(gradient_of(scm), secs_run = secs)
report("invader", out$invader)
cat(sprintf("the invader's J against the stand's: %+.2e\n", out$invader$J / out$stand$J - 1))
if (nzchar(out_file)) saveRDS(out, out_file)
