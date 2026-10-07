# The shared schedule chosen from the pilot (prereg.txt, "The shared schedule from
# the pilot"): the pilot's three walks' shares of J', read onto the run's
# introductions, choose one subset (emulate.R's rule_b on their largest share at
# 0.03); every invader of thin.R is walked and swept on it, and the stand's
# invader differenced at a relative step of 1e-4.
#
#   PLANT_LIB=... REGIME=long-drought OUT=pthin_ld.rds \
#     Rscript docs/measurements/node-rule/pilot_thin.R      # from plant-dev's root
local({
  source("harness/long_drought.R")
})
source("docs/measurements/pathfinders/invader-thinning/emulate.R")
D <- Sys.getenv("DEV")
regime <- Sys.getenv("REGIME")
out_file <- Sys.getenv("OUT")
order_inv <- c("stand=1", "lma=0.5", "lma=0.7", "hmat=0.5", "hmat=0.7", "lma=1.4",
               "hmat=1.4", "lma=2", "hmat=2")
scen <- sprintf("%s, seed %d", regime, RAIN_SPECS[[regime]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[regime]]
ev_for <- function(p) events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
params_for <- function(k, at) {
  kv <- strsplit(k, "=")[[1]]
  if (kv[1] == "stand") stand_at(at) else stand_at(at, kv[1], as.numeric(kv[2]))
}
per_node <- function(scm, q) {
  sp <- scm$patch$species[[1]]
  b <- sp$node_times
  list(birth = b, w = sp$establishment_weights, nrr = sp$net_reproduction_ratio_by_node,
       pd = sp$patch_densities, S_D = q$strategies[[1]]$pars[["S_D"]],
       br = vapply(b, function(t) sp$extrinsic_drivers$evaluate("birth_rate", t), 0))
}

# The pilot: 54 introductions at 1e-3 with the soil alone, and its three walks.
pt <- uniform_times(54)
pp <- stand_at(pt)
pc <- control_tf24(1e-3, Control(node_density_in_birth_date = TRUE))
pc$ode_soil_alone_share <- 0.1
pilot <- run_scm(pp, mkenv(scen), pc, events = ev_for(pp), record_trajectory = TRUE)
density_at <- function(k, b_run) {
  q <- params_for(k, pt)
  pilot$run_mutant(q)
  nd <- per_node(pilot, q)
  n <- length(nd$birth)
  hat <- diff(c(nd$birth[1], (nd$birth[-1] + nd$birth[-n]) / 2, T_END))
  g <- nd$w[1:n] * nd$nrr * nd$pd * nd$S_D * nd$br / hat
  y <- exp(approx(nd$birth, log(pmax(g, 1e-300)), xout = b_run, rule = 2)$y)
  y / sum(y)
}

times <- readRDS(file.path(D, "window/t/t_u108.rds"))
shared <- apply(sapply(c("stand=1", "lma=0.5", "lma=2"), density_at, b_run = times), 1, max)
keep <- rule_b(list(birth = times, w = c(shared, 0), nrr = rep(1, length(shared)), pd = 1,
                    S_D = 1, br = 1), 0.03)

# The run, as thin.R's.
p <- stand_at(times)
ct <- control_tf24(3e-5, Control(node_density_in_birth_date = TRUE,
                                 ode_split_sign_changes = TRUE))
ct$ode_soil_alone_share <- 0.1
w <- readRDS(file.path(D, sprintf("window/rule_A/weight_%s.rds", regime)))
ct$ode_weight_times <- w$t
ct$ode_weight_factors <- w$weight
scm <- run_scm(p, mkenv(scen), ct, events = ev_for(p), record_trajectory = TRUE)
out <- list(regime = regime, keep = keep, node_times = times, stand_times = scm$ode_times,
            J = sum(scm$offspring_production), cases = list(), lib = Sys.getenv("PLANT_LIB"))
for (k in order_inv) {
  q <- params_for(k, times[keep])
  r <- tryCatch({
    scm$run_mutant(q)
    J <- sum(scm$offspring_production)
    g <- stand_gradient(scm, metrics = "offspring_production")
    pars <- q$strategies[[1]]$pars
    grad <- g$gradient["offspring_production", ]
    theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
    list(J = J, elasticity = ifelse(theta == 0, 1, theta) * grad / J)
  }, error = function(e) list(error = conditionMessage(e)))
  out$cases[[k]] <- r
  saveRDS(out, out_file)
}
# The selection gradient by central differences of walks on the schedule.
for (tr in c("lma", "a_dG2")) {
  q0 <- params_for("stand=1", times[keep])
  base <- q0$strategies[[1]]$pars[[tr]]
  h <- 1e-4
  Jat <- function(f) {
    q <- q0
    pars <- q$strategies[[1]]$pars
    pars[[tr]] <- base * f
    strategies <- q$strategies
    strategies[[1]]$pars <- pars
    q$strategies <- strategies
    scm$run_mutant(q)
    sum(scm$offspring_production)
  }
  out$difference[[tr]] <- (log(Jat(1 + h)) - log(Jat(1 - h))) / (log(1 + h) - log(1 - h))
  saveRDS(out, out_file)
}
out$finished <- TRUE
saveRDS(out, out_file)
cat(sprintf("%s finished: %d of %d introductions kept\n", regime, length(keep), length(times)))
