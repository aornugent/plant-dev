# Step 2: real thinned walks and sweeps on the probe build (pf-invader-subset).
# One record's stand under the bounded setting, then for each invader its full
# walk and sweep and one per rule, each schedule a subset of the run's
# introductions chosen from step 1's full walks (walks.R). Keeps J', the
# elasticities, the per-node data and each phase's time. Last, central
# differences of the thinned stand's invader in lma and a_dG2, against its sweep.
#
#   PLANT_LIB=pf_thin/lib REGIME=long-drought RULES="b 0.1;union 0.03" \
#     OUT=runs/step2_ld.rds Rscript step2.R
local({
  source("harness/long_drought.R")
})
source("emulate.R")
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
regime <- Sys.getenv("REGIME")
out_file <- Sys.getenv("OUT")
rules <- strsplit(Sys.getenv("RULES"), ";")[[1]]
order_inv <- c("stand=1", "lma=0.5", "lma=0.7", "hmat=0.5", "hmat=0.7", "lma=1.4", "hmat=1.4", "lma=2", "hmat=2")
step1 <- readRDS(sprintf("runs/walks_%s.rds", regime))

seed <- RAIN_SPECS[[regime]]$seed
scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
knots <- active_knots(scen)
times <- readRDS(file.path(D, "window/t/t_u108.rds"))
tol <- 3e-5
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- 1e-4 * tol
ct$node_density_in_birth_date <- TRUE
ct$ode_weight_soil <- 10
w <- readRDS(file.path(D, sprintf("window/rule_A/weight_%s.rds", regime)))
ct$ode_weight_times <- w$t
ct$ode_weight_factors <- w$weight
ct$ode_weight_max <- 100
ct$ode_step_size_max <- 15 / 365
ev <- events(events_default(p), pulse_rows(sort(unique(knots))))

# The kept introductions for one rule: per invader from its own full walk's
# shares, or one schedule from the largest share over the nine.
union_s <- apply(sapply(step1$walks, function(w) shares_of(w$nodes)), 1, max)
keep_for <- function(rule, k) {
  kv <- strsplit(rule, " ")[[1]]; v <- as.numeric(kv[2]); nd <- step1$walks[[k]]$nodes
  switch(kv[1], a = rule_a(nd, v), b = rule_b(nd, v),
         union = rule_b(list(birth = nd$birth, w = c(union_s, 0), nrr = rep(1, length(union_s)),
                             pd = 1, S_D = 1, br = 1), v))
}
params_for <- function(k, at) {
  kv <- strsplit(k, "=")[[1]]
  if (kv[1] == "stand") { q <- p; q$node_schedule_times <- list(at); q } else stand_at(at, kv[1], as.numeric(kv[2]))
}
clock <- function() proc.time()[["elapsed"]]
per_node <- function(scm) {
  sp <- scm$patch$species[[1]]
  state <- matrix(sp$ode_state, ncol = sp$size, dimnames = list(sp$new_node$ode_names))
  list(birth = sp$node_times, w = sp$establishment_weights, nrr = sp$net_reproduction_ratio_by_node,
       E = state["interval_establishment", ], M = state["interval_establishment_moment", ])
}
gradient_of <- function(scm, q) {
  g <- stand_gradient(scm, metrics = "offspring_production")
  pars <- q$strategies[[1]]$pars
  grad <- g$gradient["offspring_production", ]
  theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
  J <- sum(scm$offspring_production)
  list(value = unname(g$value), gradient = grad, theta = theta,
       elasticity = ifelse(theta == 0, 1, theta) * grad / J, refusal = g$refusal[["offspring_production"]])
}
walk <- function(q) {
  t0 <- clock()
  r <- tryCatch({ scm$run_mutant(q); TRUE }, error = function(e) conditionMessage(e))
  t1 <- clock()
  if (!isTRUE(r)) return(list(error = r, walk_secs = t1 - t0))
  v <- list(J = sum(scm$offspring_production), nodes = per_node(scm), walk_secs = t1 - t0)
  g <- tryCatch(gradient_of(scm, q), error = function(e) conditionMessage(e))
  v$sweep_secs <- clock() - t1
  if (is.character(g)) v$gradient_error <- g else v <- c(v, g)
  v
}

out <- list(regime = regime, rules = rules, cases = list())
t0 <- clock()
scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
out$stand <- list(J = sum(scm$offspring_production), times = scm$ode_times, secs = clock() - t0)
stopifnot(identical(out$stand$J, step1$stand$J))
saveRDS(out, out_file)
for (k in order_inv) {
  out$cases[[k]] <- list(full = walk(params_for(k, times)))
  saveRDS(out, out_file)
  for (rule in rules) {
    kp <- keep_for(rule, k)
    v <- walk(params_for(k, times[kp]))
    v$keep <- kp
    out$cases[[k]][[rule]] <- v
    saveRDS(out, out_file)
  }
}
# The sweep on a thinned walk against central differences of thinned walks, each
# trait set alone as the sweep's column is (not through the hyperparameters).
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
