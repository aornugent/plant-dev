# The refine loop (harness/schedule/refine.R) under two judged sets, on one case:
#   A: ln J and the resident's elasticities (as built);
#   B: ln J and the invader's g at theta' = theta (its elasticities d ln R'/d ln theta').
# Every run takes the forward, the resident sweep, and the invader walk and sweep, each timed
# apart, so each set's loop is replayed from one cache of runs by level and charged only the
# parts it needs. Runs are deterministic, so a level both sets visit is one run.
#
#   PLANT_LIB=... Rscript spikes/refine-judged/refine_judged.R CASE OUTDIR [SCALE]
# from the plant-dev root. Each run is saved to OUTDIR/CASE/ (OUTDIR/CASE@SCALE/ off scale 1)
# as it finishes.
source(file.path(Sys.getenv("PLANT_DEV", "."), "harness/long_drought.R"))
source(file.path(Sys.getenv("PLANT_DEV", "."), "harness/schedule/refine.R"))
source(file.path(Sys.getenv("PLANT_DEV", "."), "spikes/refine-judged/cases.R"))

clock <- function() { t <- proc.time(); c(cpu = sum(t[c("user.self", "sys.self")]), wall = t[["elapsed"]]) }

# The harness's stand_run on plant 2.0.0.9002 (odelia 0.9.0): record_trajectory and
# store_trajectory() are keep_states and store_recording(). Adds the invader at the run's own
# traits and introductions, walked in the run's recording and swept.
stand_run <- function(p, env, ctrl, times, base = NULL, gradient = TRUE, records = FALSE) {
  p$node_schedule_times <- list(times)
  if (!is.null(base)) {
    p$ode_times <- base$stand$times; p$ode_step_sizes <- base$stand$sizes
    p$ode_soil_input_slopes <- base$stand$input_slopes; p$ode_soil_substep_ends <- base$stand$substep_ends
  }
  cost <- matrix(0, 4, 2, dimnames = list(c("forward", "sweep", "walk", "walk_sweep"), c("cpu", "wall")))
  types <- plant:::extract_RcppR6_template_types(p, "Parameters")
  scm <- do.call(plant:::SCM, types)(p, env, events(), ctrl)
  scm$keep_states <- TRUE
  c0 <- clock(); scm$run(); cost["forward", ] <- clock() - c0; sp <- scm$patch$species[[1]]
  x <- list(node_times = times, stand = list(J = sum(scm$offspring_production), times = scm$ode_times,
            sizes = scm$ode_step_sizes, input_slopes = scm$ode_soil_input_slopes,
            substep_ends = scm$ode_soil_substep_ends,
            nodes = list(birth = sp$node_times, nrr = sp$net_reproduction_ratio_by_node)))
  if (records) {
    rows <- scm$store_recording(); per <- length(sp$ode_state) / sp$size; nm <- sp$new_node$ode_names
    len <- lengths(lapply(rows, `[[`, "state")); held <- (len - (tail(len, 1) - per * sp$size)) / per
    t <- vapply(rows, `[[`, 0, "time"); w <- sp$establishment_weights
    at <- function(i, j, name) rows[[i]]$state[per * (j - 1) + which(nm == name)]
    E <- vapply(seq_along(rows), function(i) if (held[i] > 0) at(i, held[i], "interval_establishment") else NA_real_, 0)
    O <- vapply(seq_along(rows), function(i) sum(w[seq_len(held[i])] * at(i, seq_len(held[i]), "offspring_produced_survival_weighted")), 0)
    k <- which(diff(held) == 0 & diff(t) > 0)
    x$establishment <- list(start = t[k], end = t[k + 1], rate = (E[k + 1] - E[k]) / (t[k + 1] - t[k]))
    x$remaining <- list(time = t, share = 1 - O / tail(O, 1))
  }
  if (gradient) {
    pars <- c(p$strategies[[1]]$pars, birth_rate = p$strategies[[1]]$birth_rate_y[[1]])
    elasticity <- function(g, J) {
      grad <- setNames(g$gradient[[1]], plant:::census_trait_names_tf24(scm))
      theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
      ifelse(theta == 0, 1, theta) * grad / J
    }
    c0 <- clock(); g <- plant:::census_trait_gradient_tf24(scm, METRIC); cost["sweep", ] <- clock() - c0
    x$stand$elasticity <- elasticity(g, x$stand$J)
    x$refusal <- g$refusal[[METRIC]]
    c0 <- clock(); scm$run_mutant(p); cost["walk", ] <- clock() - c0
    x$invader <- list(J = sum(scm$offspring_production))
    c0 <- clock(); g <- plant:::census_trait_gradient_tf24(scm, METRIC); cost["walk_sweep", ] <- clock() - c0
    x$invader$elasticity <- elasticity(g, x$invader$J)
    x$invader$refusal <- g$refusal[[METRIC]]
  }
  x$cost <- cost
  x
}
METRIC <- "1.offspring_production"
# birth_rate is the balance's b: d ln J / d ln b is not judged, and its constants were never measured.
UNMEASURED <- c(UNMEASURED, "birth_rate")

# Every quantity a run carries, named by role: lnJ, the resident's elasticities, and g.<trait>,
# the invader's.
all_quantities <- function(x) {
  for (r in list(x$refusal, x$invader$refusal)) if (!is.null(r) && length(r) && nzchar(r)) stop("gradient refused: ", r)
  q <- quantities(x, UNMEASURED)
  gi <- unname(x$invader$elasticity); names(gi) <- paste0("g.", sub("^1\\.", "", names(x$invader$elasticity)))
  q <- c(q, gi[!sub("^g\\.", "", names(gi)) %in% UNMEASURED])
  if (any(!is.finite(q))) stop("non-finite quantities: ", paste(names(q)[!is.finite(q)], collapse = ", "))
  q
}
eps_all <- function(n) {
  inv <- startsWith(n, "g.")
  out <- eps_vec(sub("^g\\.", "", n))
  out[inv] <- vapply(sub("^g\\.", "", n[inv]), function(m) {
    e <- eps_tab$eps[eps_tab$role == "invader" & eps_tab$trait == m & eps_tab$unit != "curvature in lma"]
    max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE) }, 0)
  setNames(out, n)
}
JUDGED <- list(A = function(n) n == "lnJ" | !startsWith(n, "g."),
               B = function(n) n == "lnJ" | startsWith(n, "g."))
CHARGED <- list(A = c("forward", "sweep"), B = c("forward", "walk", "walk_sweep"))

# The loop of refine_schedule, judging the quantities `set` selects, on cached runs. It carries
# every quantity's estimate along, judged or not, so the unjudged ones can be scored too.
refine_judged <- function(set, run_at, first, sch) {
  history <- list(); level <- 0; used <- c("first", "level0", "level0_replay")
  x <- run_at(0); q <- all_quantities(x); r <- run_at(0, replay = TRUE)
  e <- (all_quantities(r)[names(q)] - q) / 3 / eps_all(names(q)); unestimated <- UNESTIMATED_REPLAY
  judge <- JUDGED[[set]](names(q))
  repeat {
    bound <- CORRECTED_SHARE * abs(e) + unestimated
    jb <- bound[judge]
    history[[length(history) + 1]] <- list(level = level, nodes = length(nodes_of(sch, level)),
                                           worst = names(jb)[which.max(jb)], worst_bound = max(jb))
    status <- if (all(jb < 1)) "converged" else if (length(history) == PASSES || level == MAX_LEVEL) "unconverged" else NA
    if (!is.na(status)) break
    k <- 1
    while (max(CORRECTED_SHARE * abs(e[judge]) / 4^k + UNESTIMATED_PAIR) > PREDICTED_BOUND_MAX && level + k < MAX_LEVEL) k <- k + 1
    y <- run_at(level + k); qy <- all_quantities(y)[names(q)]
    e <- (q - qy) / (4^k - 1) / eps_all(names(q)); unestimated <- UNESTIMATED_PAIR
    level <- level + k; q <- qy; used <- c(used, paste0("level", level))
  }
  list(set = set, status = status, level = level, passes = length(history), nodes = length(nodes_of(sch, level)),
       runs = used, answer = q - e * eps_all(names(q)), run = q, estimate = e, bound = bound, judged = judge,
       history = history)
}

if (sys.nframe() == 0) {
  a <- commandArgs(TRUE); case <- a[1]; scale <- if (length(a) > 2) as.numeric(a[3]) else 1
  dir <- file.path(a[2], if (scale == 1) case else paste0(case, "@", scale)); dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  setup <- case_setup(case)
  cached <- function(name, f) {
    path <- file.path(dir, paste0(name, ".rds"))
    if (file.exists(path)) return(readRDS(path))
    c0 <- Sys.time(); x <- f(); saveRDS(x, path)
    message(sprintf("%s %s: %.1f min", case, name, as.numeric(Sys.time() - c0, units = "mins"))); x
  }
  # The first run does not depend on the scale.
  if (scale != 1 && !file.exists(file.path(dir, "first.rds")) && file.exists(file.path(a[2], case, "first.rds")))
    file.copy(file.path(a[2], case, "first.rds"), dir)
  first <- cached("first", function() stand_run(setup$p, setup$env, setup$ctrl, seq(0, HORIZON, length.out = 100),
                                                 gradient = FALSE, records = TRUE))
  sch <- schedule_of(first, setup$p$strategies[[1]]$pars, scale)
  run_at <- function(k, replay = FALSE) {
    if (replay) {
      base <- run_at(0); half <- nodes_of(sch, 0, half = TRUE); stopifnot(nested(half, base$node_times))
      return(cached("level0_replay", function() stand_run(setup$p, setup$env, setup$ctrl, half, base = base)))
    }
    cached(paste0("level", k), function() stand_run(setup$p, setup$env, setup$ctrl, nodes_of(sch, k)))
  }
  fits <- lapply(names(JUDGED), function(s) refine_judged(s, run_at, first, sch))
  names(fits) <- names(JUDGED)
  saveRDS(list(case = case, scale = scale, schedule = sch, fits = fits), file.path(dir, "fits.rds"))
  for (f in fits) message(sprintf("%s %s: %s at level %d after %d passes, %d nodes, worst %s %.2f", case, f$set,
                                  f$status, f$level, f$passes, f$nodes, tail(f$history, 1)[[1]]$worst,
                                  tail(f$history, 1)[[1]]$worst_bound))
}
