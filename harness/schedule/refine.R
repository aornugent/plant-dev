# Refine a TF24 node schedule until every quantity's error bound is under its eps
# (docs/schedule/refine.md). Source harness/long_drought.R first; paths are relative to
# PLANT_DEV, the plant-dev checkout (default: the working directory).
#
# fit <- refine_schedule(p, env, ctrl, scale = 1): p carries one strategy, env its rainfall,
# ctrl the run's control. Returns list(answer, estimate, bound, run, schedule, level, history,
# costs, status, error): the answer is the last run corrected by its estimate (run - estimate),
# and node times are nodes_of(fit$schedule, fit$level).
source(file.path(Sys.getenv("PLANT_DEV", "."), "harness/schedule/quantities.R"))
HORIZON <- 107 * LIFETIME / 108

# The bound on the corrected answer's node-schedule error: CORRECTED_SHARE |e| + UNESTIMATED, the
# short spells after a replay or the step changes between the runs of a doubled pair. The ODE
# tolerance's own error is the step controller's to hold, not this bound's.
CORRECTED_SHARE <- 0.5
UNESTIMATED_REPLAY <- 0.22
UNESTIMATED_PAIR <- 0.08
PREDICTED_BOUND_MAX <- 0.9
PASSES <- 4
MAX_LEVEL <- 4
# Quantities the bound's constants were not measured on.
UNMEASURED <- c(EXCLUDED, "rooting_depth_max")

judged <- function(x) {
  if (!is.null(x$refusal)) stop("gradient refused: ", x$refusal)
  q <- quantities(x, UNMEASURED)
  if (any(!is.finite(q))) stop("non-finite quantities: ", paste(names(q)[!is.finite(q)], collapse = ", "))
  q
}

# One stand run on `times`, on the steps of `base` when given. `records` adds the establishment
# rate and T(t), the share of J still to be produced; the newest node's establishment integral
# is the only one still open, so its growth over a step is the rate.
stand_run <- function(p, env, ctrl, times, base = NULL, gradient = TRUE, records = FALSE) {
  p$node_schedule_times <- list(times)
  if (!is.null(base)) {
    p$ode_times <- base$stand$times; p$ode_step_sizes <- base$stand$sizes
    p$ode_soil_input_slopes <- base$stand$input_slopes; p$ode_soil_substep_ends <- base$stand$substep_ends
  }
  cpu <- function() sum(proc.time()[c("user.self", "sys.self")])
  types <- plant:::extract_RcppR6_template_types(p, "Parameters")
  scm <- do.call(plant:::SCM, types)(p, env, events(events_default(p)), ctrl)
  scm$keep_states <- TRUE
  c0 <- cpu(); scm$run(); sp <- scm$patch$species[[1]]
  x <- list(node_times = times, stand = list(J = sum(scm$offspring_production), times = scm$ode_times,
            sizes = scm$ode_step_sizes, input_slopes = scm$ode_soil_input_slopes,
            substep_ends = scm$ode_soil_substep_ends,
            nodes = list(birth = sp$node_times, nrr = sp$net_reproduction_ratio_by_node)),
            cpu = c(forward = cpu() - c0, sweep = 0))
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
    c0 <- cpu(); g <- plant:::census_trait_gradient_tf24(scm, "1.offspring_production"); x$cpu[["sweep"]] <- cpu() - c0
    grad <- setNames(g$gradient[[1]], plant:::census_trait_names_tf24(scm)); grad <- grad[names(grad) != "1.birth_rate"]; pars <- p$strategies[[1]]$pars
    theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
    x$stand$elasticity <- ifelse(theta == 0, 1, theta) * grad / x$stand$J
    x$refusal <- g$refusal[["1.offspring_production"]]
  }
  x
}

# Spell edges from the first run's establishment rate, and the ages t50 and t90, when half and
# 90% of J have been produced. A record that never closes is one spell to the horizon.
spells_of <- function(first) {
  er <- first$establishment; open <- er$rate > 0.01
  r <- rle(open); e <- cumsum(r$lengths); b <- er$end[e][-length(e)]; ending <- open[e][-length(e)]
  k <- b > 0 & b < HORIZON
  remaining <- first$remaining
  if (!all(is.finite(remaining$share))) stop("the first run produced no offspring")
  age <- function(s) { t <- remaining$time[which(remaining$share <= s)[1]]; if (is.na(t)) HORIZON else t }
  b1 <- b[k][ending[k]][1]
  list(edges = b[k], ending = ending[k], b1 = if (is.na(b1)) HORIZON else b1, t50 = age(0.5), t90 = age(0.1),
       shut = approxfun(c(er$start, tail(er$end, 1)), c(!open, !tail(open, 1)), method = "constant", rule = 2))
}

# Node spacing from the offspring curve: fine over the first cohorts' steep fall, capped at
# 100 d until t50 and 280 d after, wider where offspring are far below the spells' median.
spacing_of <- function(first, sp) {
  n <- first$stand$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  early <- n$birth < sp$b1; y <- log(pmax(n$nrr[early], 1e-30)); fall <- log(n$nrr[1] / 10)
  i <- which(y < fall)[1]
  l1 <- if (is.na(i)) sp$b1 else if (i == 1) 0 else
    n$birth[i - 1] + (y[i - 1] - fall) / (y[i - 1] - y[i]) * (n$birth[i] - n$birth[i - 1])
  later <- n$birth > sp$b1 & n$birth < max(sp$t50, sp$b1 + 1)
  ref <- median(log(pmax(n$nrr[if (any(later)) later else n$birth >= sp$b1], 1e-300)))
  function(b) {
    cap <- if (b < sp$b1) sp$b1 / 12 else if (b < sp$t50) 100 / 365 else 280 / 365
    min(cap, if (b < sp$b1) { if (b < l1) sp$b1 / 24 else sp$b1 / 12 } else 90 / 365 * max(1, exp(0.2 * (ref - lf(b))))) }
}

# Twice the density up to 0.95 t_r before each spell end, falling to 1 by 1.4 t_r, where t_r is
# the time a newborn's reserves take to run down: o ln(a_st3 a_dG2).
grade <- function(days, t_r) 1 + pmin(1, pmax(0, (1.4 - days / t_r) / 0.45))
reserve_time <- function(pars) pars$storage_relaxation_offset * 365 * log(pars$a_st3 * pars$a_dG2)

# Panels between breakpoints (0, every edge up to t90, the horizon); one panel per spell up to
# t90, one for everything after. Each panel's count is 0 (no establishment), 1 (density mass at
# most one) or even plus two; level k multiplies it by 2^k.
schedule_of <- function(first, pars, scale = 1) {
  sp <- spells_of(first); h <- spacing_of(first, sp); t_r <- reserve_time(pars)
  br <- sort(unique(c(0, sp$edges[sp$edges <= sp$t90], HORIZON)))
  g <- seq(0, HORIZON, length.out = 40001); dg <- g[2] - g[1]; gm <- g[-1] - dg / 2
  open <- sp$shut(gm) < 0.5
  ends <- sp$edges[sp$ending & sp$edges <= sp$t90]
  nx <- ends[pmin(findInterval(gm, ends) + 1, length(ends) + 1)]
  days <- ifelse(is.na(nx), Inf, (nx - gm) * 365)
  rho <- ifelse(open, 1 / vapply(gm, h, 0), 0) * ifelse(is.finite(days), grade(days, t_r), 1)
  panels <- lapply(seq_len(length(br) - 1), function(i) {
    k <- gm >= br[i] & gm < br[i + 1]; m <- scale * sum(rho[k]) * dg
    n <- if (!any(open[k])) 0 else if (m <= 1 + 1e-9) 1 else 2 * ceiling(m / 2 - 1e-9) + 2
    list(lo = br[i], hi = br[i + 1], n = n, mass = c(0, cumsum(rho[k] * dg)),
         at = pmin(c(br[i], gm[k] + dg / 2), br[i + 1])) })
  list(breaks = br, panels = panels, spells = sp, t_r = t_r, scale = scale)
}

# Node times at level k; `half` keeps every other interior node of each panel holding two or more
# intervals, the replay's schedule.
nodes_of <- function(sch, k, half = FALSE) {
  S <- unlist(lapply(sch$panels, function(p) {
    n <- p$n * 2^k; if (half && n >= 2) n <- n / 2
    if (n < 2) return(p$lo)
    c(p$lo, approx(p$mass / tail(p$mass, 1), p$at, seq(0, 1, length.out = n + 1)[2:n], ties = "ordered")$y) }))
  sort(unique(round(S, 10)))
}
nested <- function(coarse, fine) all(round(coarse, 10) %in% round(fine, 10))

refine_schedule <- function(p, env, ctrl, scale = 1) {
  history <- list(); costs <- list(); level <- 0; q <- e <- unestimated <- sch <- NULL; unpinned <- NULL
  fit <- function(status, error = NULL) list(
    answer = if (is.null(e)) q else q - e * eps_vec(names(q)), estimate = e,
    bound = if (is.null(e)) NULL else CORRECTED_SHARE * abs(e) + unestimated, run = q,
    schedule = sch, level = level, history = history, costs = do.call(rbind, costs),
    status = status, error = error, replay_unpinned = unpinned)
  tryCatch({
    first <- stand_run(p, env, ctrl, seq(0, HORIZON, length.out = 100), gradient = FALSE, records = TRUE)
    costs$first <- first$cpu
    sch <- schedule_of(first, p$strategies[[1]]$pars, scale)
    S <- nodes_of(sch, 0); half <- nodes_of(sch, 0, half = TRUE); stopifnot(nested(half, S))
    x <- stand_run(p, env, ctrl, S); costs$level0 <- x$cpu; q <- judged(x)
    # On crown-integral a replay pinned to the run's steps is refused where the coarser node set
    # would substep the soil at a time the fine run did not; then replay on the coarse run's own
    # steps, which adds step-sequence noise to the estimate (refine.md: rms ~0.04 eps), and say so.
    r <- tryCatch(stand_run(p, env, ctrl, half, base = x), error = function(e) {
      if (!grepl("would substep", conditionMessage(e))) stop(e)
      y <- stand_run(p, env, ctrl, half); y$replay_unpinned <- conditionMessage(e); y })
    unpinned <- r$replay_unpinned; costs$level0_replay <- r$cpu
    e <- (judged(r)[names(q)] - q) / 3 / eps_vec(names(q)); unestimated <- UNESTIMATED_REPLAY
    repeat {
      bound <- CORRECTED_SHARE * abs(e) + unestimated
      history[[length(history) + 1]] <- list(level = level, nodes = length(S), answer = q, estimate = e,
                                             worst = names(q)[which.max(bound)], worst_bound = max(bound))
      if (all(bound < 1)) return(fit("converged"))
      if (length(history) == PASSES || level == MAX_LEVEL) return(fit("unconverged"))
      k <- 1
      while (max(CORRECTED_SHARE * abs(e) / 4^k + UNESTIMATED_PAIR) > PREDICTED_BOUND_MAX && level + k < MAX_LEVEL) k <- k + 1
      finer <- nodes_of(sch, level + k); stopifnot(nested(S, finer))
      y <- stand_run(p, env, ctrl, finer); costs[[paste0("level", level + k)]] <- y$cpu
      qy <- judged(y)[names(q)]
      e <- (q - qy) / (4^k - 1) / eps_vec(names(q)); unestimated <- UNESTIMATED_PAIR
      level <- level + k; S <- finer; q <- qy
    }
  }, error = function(err) fit("failed", conditionMessage(err)))
}
