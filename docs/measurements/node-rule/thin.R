# The invader's own rule (6.4; prereg.txt, "The thinning"): real thinned walks and
# sweeps, each schedule a subset of the run's introductions chosen from that
# invader's own full walk on this build (emulate.R's rule b) or from the nine
# full walks' largest shares (union). Keeps J', the elasticities, the per-node
# data and each walk's and sweep's time; last, central differences of the
# stand's invader thinned, in lma and a_dG2, against its sweep.
#
#   PLANT_LIB=... REGIME=long-drought RULES="b 0.1;union 0.03" OUT=thin_ld.rds \
#     Rscript docs/measurements/node-rule/thin.R      # from plant-dev's root
local({
  source("harness/long_drought.R")
})
source("docs/measurements/pathfinders/invader-thinning/emulate.R")
D <- Sys.getenv("DEV")
regime <- Sys.getenv("REGIME")
out_file <- Sys.getenv("OUT")
rules <- strsplit(Sys.getenv("RULES"), ";")[[1]]
order_inv <- c("stand=1", "lma=0.5", "lma=0.7", "hmat=0.5", "hmat=0.7", "lma=1.4",
               "hmat=1.4", "lma=2", "hmat=2")

seed <- RAIN_SPECS[[regime]]$seed
scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
times <- readRDS(file.path(D, "window/t/t_u108.rds"))
p <- stand_at(times)
ct <- control_tf24(3e-5, Control(node_density_in_birth_date = TRUE,
                                 ode_split_sign_changes = TRUE))
ct$ode_soil_alone_share <- 0.1
w <- readRDS(file.path(D, sprintf("window/rule_A/weight_%s.rds", regime)))
ct$ode_weight_times <- w$t
ct$ode_weight_factors <- w$weight
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))

params_for <- function(k, at) {
  kv <- strsplit(k, "=")[[1]]
  if (kv[1] == "stand") stand_at(at) else stand_at(at, kv[1], as.numeric(kv[2]))
}
clock <- function() proc.time()[["elapsed"]]
per_node <- function(scm, q) {
  sp <- scm$patch$species[[1]]
  state <- matrix(sp$ode_state, ncol = sp$size, dimnames = list(sp$new_node$ode_names))
  b <- sp$node_times
  list(birth = b, w = sp$establishment_weights, nrr = sp$net_reproduction_ratio_by_node,
       pd = sp$patch_densities, E = state["interval_establishment", ],
       M = state["interval_establishment_moment", ], S_D = q$strategies[[1]]$pars[["S_D"]],
       br = vapply(b, function(t) sp$extrinsic_drivers$evaluate("birth_rate", t), 0),
       splits = scm$ode_splits)
}
gradient_of <- function(scm, q) {
  g <- stand_gradient(scm, metrics = "offspring_production")
  pars <- q$strategies[[1]]$pars
  grad <- g$gradient["offspring_production", ]
  theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
  J <- sum(scm$offspring_production)
  list(gradient = grad, elasticity = ifelse(theta == 0, 1, theta) * grad / J,
       refusal = g$refusal[["offspring_production"]])
}
walk <- function(q) {
  t0 <- clock()
  r <- tryCatch({ scm$run_mutant(q); TRUE }, error = function(e) conditionMessage(e))
  t1 <- clock()
  if (!isTRUE(r)) return(list(error = r, walk_secs = t1 - t0))
  v <- list(J = sum(scm$offspring_production), nodes = per_node(scm, q), walk_secs = t1 - t0)
  g <- tryCatch(gradient_of(scm, q), error = function(e) conditionMessage(e))
  v$sweep_secs <- clock() - t1
  if (is.character(g)) v$gradient_error <- g else v <- c(v, g)
  v
}

out <- list(regime = regime, rules = rules, node_times = times, cases = list(),
            lib = Sys.getenv("PLANT_LIB"))
t0 <- clock()
scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
out$stand <- list(J = sum(scm$offspring_production), times = scm$ode_times,
                  secs = clock() - t0)
saveRDS(out, out_file)
for (k in order_inv) {
  out$cases[[k]] <- list(full = walk(params_for(k, times)))
  saveRDS(out, out_file)
}
union_s <- apply(sapply(out$cases, function(x) shares_of(x$full$nodes)), 1, max)
keep_for <- function(rule, k) {
  kv <- strsplit(rule, " ")[[1]]; v <- as.numeric(kv[2]); nd <- out$cases[[k]]$full$nodes
  switch(kv[1], a = rule_a(nd, v), b = rule_b(nd, v),
         union = rule_b(list(birth = nd$birth, w = c(union_s, 0), nrr = rep(1, length(union_s)),
                             pd = 1, S_D = 1, br = 1), v))
}
for (k in order_inv) for (rule in rules) {
  kp <- keep_for(rule, k)
  v <- walk(params_for(k, times[kp]))
  v$keep <- kp
  out$cases[[k]][[rule]] <- v
  saveRDS(out, out_file)
}
with_parameter <- function(q, name, value) {
  strategies <- q$strategies
  pars <- strategies[[1]]$pars
  pars[[name]] <- value
  strategies[[1]]$pars <- pars
  q$strategies <- strategies
  q
}
fd <- list()
for (rule in rules) {
  kp <- keep_for(rule, "stand=1")
  for (tr in c("lma", "a_dG2")) {
    q0 <- params_for("stand=1", times[kp])
    base <- q0$strategies[[1]]$pars[[tr]]
    h <- 1e-3
    Jat <- function(f) {
      scm$run_mutant(with_parameter(q0, tr, base * f))
      sum(scm$offspring_production)
    }
    d <- (log(Jat(1 + h)) - log(Jat(1 - h))) / (log(1 + h) - log(1 - h))
    fd[[length(fd) + 1]] <- data.frame(rule = rule, trait = tr, difference = d,
      swept = unname(out$cases[["stand=1"]][[rule]]$elasticity[paste0("1.", tr)]))
    out$fd <- do.call(rbind, fd)
    saveRDS(out, out_file)
  }
}
out$finished <- format(Sys.time(), tz = "UTC", usetz = TRUE)
saveRDS(out, out_file)
cat(sprintf("%s finished, %.0f s\n", regime, clock() - t0))
