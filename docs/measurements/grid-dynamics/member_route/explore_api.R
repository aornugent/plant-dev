# Feasibility: an invader member's rates in the resident's field, through a
# standalone Node evaluated in a copy of the resident patch's environment. Checks
# that the route reproduces a resident member's in-patch rates exactly, and
# times each call.
#   PLANT_LIB=$DEV/lib_guard Rscript explore_api.R
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/spike_methods"
D <- dirname(S)
source(file.path(S, "snap/harness/long_drought.R"))
times <- readRDS(file.path(D, "window/t/t_u108.rds"))
stopifnot(isTRUE(all.equal(times, uniform_times(108))))
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- 3e-5
ct$ode_tol_abs <- 1e-4 * 3e-5
ct$node_density_in_birth_date <- TRUE
env <- mkenv("long-drought")
patch <- plant:::Patch("TF24", "TF24_Env")(p, env, ct)
# a few nodes, stepped crudely so the members differ
for (k in 1:6) {
  patch$introduce_new_node(1L, times[k])
  y <- patch$ode_state
  t <- times[k]
  for (i in 1:20) {
    h <- (times[k + 1] - times[k]) / 20
    d <- patch$derivs(y, t)
    y <- y + h * d
    t <- t + h
  }
  patch$set_ode_state(y, t)
}
t <- patch$time
cat("patch time", t, "nodes", patch$species[[1]]$size, "ode size", length(y), "\n")
d <- patch$derivs(y, t)
sp <- patch$species[[1]]
nodes <- sp$nodes
cat("node ode names:", paste(nodes[[1]]$ode_names, collapse = ", "), "\n")
e <- patch$environment
pr <- patch$pr_survival(t)
worst <- 0
for (j in seq_along(nodes)) {
  nd <- nodes[[j]]
  nd$compute_rates(e, pr)
  r <- nd$ode_rates
  ref <- d[9 * (j - 1) + 1:9]
  worst <- max(worst, max(abs(r - ref) / pmax(abs(ref), 1e-300)))
  if (j <= 2) print(rbind(node = r, patch = ref))
}
cat("largest relative difference, node route against in-patch rates:", worst, "\n")

# The invader's template: the boundary node of a patch holding the invader alone,
# as run_record.R's INVADERS builds it (stand_at) for scm$run_mutant.
patch2 <- plant:::Patch("TF24", "TF24_Env")(stand_at(times, "lma", 2), env, ct)
inv <- patch2$species[[1]]$new_node
br <- patch2$species[[1]]$extrinsic_drivers$evaluate("birth_rate", t)
cat("invader birth rate", br, "resident", sp$extrinsic_drivers$evaluate("birth_rate", t), "\n")
inv$compute_initial_conditions(e, pr, br)
cat("invader initial state:", format(inv$ode_state, digits = 4), "\n")
inv$compute_rates(e, pr)
cat("invader rates:", format(inv$ode_rates, digits = 4), "\n")
cat("lma of the invader's strategy:", inv$individual$strategy$lma, "\n")

# Timing
tm <- function(f, n = 200) { t0 <- proc.time()[["elapsed"]]; for (i in seq_len(n)) f(); (proc.time()[["elapsed"]] - t0) / n * 1e3 }
cat(sprintf("ms per call: derivs %.3f, set_ode_state %.3f, environment copy %.3f, node set state %.3f, node compute_rates %.3f, node ode_rates %.3f\n",
            tm(function() patch$derivs(y, t)), tm(function() patch$set_ode_state(y, t)),
            tm(function() patch$environment), tm(function() inv$ode_state <- inv$ode_state),
            tm(function() inv$compute_rates(e, pr)), tm(function() inv$ode_rates)))
