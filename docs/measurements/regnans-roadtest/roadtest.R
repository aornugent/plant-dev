# The regnans workflow on one 40-year rainfall record of the harness, TF24, every
# derivative from a sweep:
#   0. a pilot forward at b = 1 guesses the equilibrium's birth rate;
#   1. the node schedule refined at that guess (harness/schedule/refine.R, copied
#      here with the census metric renamed), then held fixed;
#   2. the resident's equilibrium by Newton in ln b on ln J - ln b, its slope from
#      the birth-rate column;
#   3. the equilibrium run as the cache; the invader's selection gradient
#      d ln R'/d ln lma along TF24_hyperpar's trade-off, by the sweep;
#   4. the landscape: invaders at lma x (0.5 ... 2), run together against the cache;
#   5. the swept gradient against central differences of invasions at two h;
#   6. one step up the landscape: the invader alone at its equilibrium, then the
#      old resident as its invader.
# Run as: PLANT_LIB=<lib> Rscript roadtest.R <climate> <out.rds>
source("/home/user/plant-dev/harness/long_drought.R")
source("/home/user/plant-dev/harness/schedule/quantities.R")
args <- commandArgs(TRUE)
climate <- args[[1]]
out_file <- args[[2]]
HILL <- Sys.getenv("HILL", "1") == "1"

log_line <- function(...) cat(sprintf(...), "\n", sep = "")
clock <- function() proc.time()[["elapsed"]]
HORIZON <- 107 * LIFETIME / 108
ENV <- mkenv(climate)
out <- list(climate = climate, times = c(), failures = list())
timed <- function(step, expr) {
  t0 <- clock()
  value <- tryCatch(expr, error = function(e) {
    out$failures[[step]] <<- conditionMessage(e)
    log_line("   FAILED in %s: %s", step, conditionMessage(e))
    NULL
  })
  out$times[[step]] <<- clock() - t0
  log_line("   [%s: %.1f s]", step, clock() - t0)
  value
}
save_out <- function() saveRDS(out, out_file)

ctrl <- control()
ctrl$ode_tol_rel <- 1e-4
ctrl$ode_tol_abs <- 1e-8
ctrl$node_density_in_birth_date <- TRUE
ctrl$ode_step_size_max <- 15 / 365

# Species at lma, each on the trade-off, all introduced at `times`.
stand <- function(lma, birth_rate, times) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(lma, "lma"), hyperpar = TF24_hyperpar,
                      birth_rate = as.list(rep_len(birth_rate, length(lma))))
  p$node_schedule_times <- rep(list(times), length(lma))
  p
}

## The schedule's refinement: harness/schedule/refine.R with the census metric
## named "1.offspring_production" and the birth-rate column kept for Newton.
CORRECTED_SHARE <- 0.5
UNESTIMATED_REPLAY <- 0.22
UNESTIMATED_PAIR <- 0.08
PREDICTED_BOUND_MAX <- 0.9
PASSES <- 4
MAX_LEVEL <- 4
UNMEASURED <- c(EXCLUDED, "rooting_depth_max", "birth_rate")

judged <- function(x) {
  if (!is.null(x$refusal)) stop("gradient refused: ", x$refusal)
  q <- quantities(x, UNMEASURED)
  if (any(!is.finite(q))) stop("non-finite quantities: ", paste(names(q)[!is.finite(q)], collapse = ", "))
  q
}

stand_run <- function(p, env, ctrl, times, base = NULL, gradient = TRUE, records = FALSE) {
  p$node_schedule_times <- list(times)
  if (!is.null(base)) {
    p$ode_times <- base$stand$times; p$ode_step_sizes <- base$stand$sizes
    p$ode_soil_input_slopes <- base$stand$input_slopes; p$ode_soil_substep_ends <- base$stand$substep_ends
  }
  cpu <- function() sum(proc.time()[c("user.self", "sys.self")])
  types <- plant:::extract_RcppR6_template_types(p, "Parameters")
  # No events: with events the schedule keeps only the times of `base`, and a
  # step that substeps the soil is then refused.
  scm <- do.call(plant:::SCM, types)(p, env, plant:::empty_events(), ctrl)
  scm$record_trajectory <- TRUE
  c0 <- cpu(); scm$run(); sp <- scm$patch$species[[1]]
  x <- list(node_times = times, stand = list(J = sum(scm$offspring_production), times = scm$ode_times,
            sizes = scm$ode_step_sizes, input_slopes = scm$ode_soil_input_slopes,
            substep_ends = scm$ode_soil_substep_ends,
            nodes = list(birth = sp$node_times, nrr = sp$net_reproduction_ratio_by_node)),
            cpu = c(forward = cpu() - c0, sweep = 0))
  if (records) {
    rows <- scm$store_trajectory(); per <- length(sp$ode_state) / sp$size; nm <- sp$new_node$ode_names
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
    c0 <- cpu(); g <- stand_gradient(scm, metrics = "1.offspring_production"); x$cpu[["sweep"]] <- cpu() - c0
    grad <- g$gradient[1, ]; pars <- p$strategies[[1]]$pars
    theta <- vapply(names(grad), function(n) {
      n <- sub("^1\\.", "", n)
      if (n == "birth_rate") p$strategies[[1]]$birth_rate_y[[1]] else pars[[n]] }, 0)
    x$stand$elasticity <- ifelse(theta == 0, 1, theta) * grad / x$stand$J
    x$refusal <- g$refusal[["1.offspring_production"]]
  }
  x
}

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

grade <- function(days, t_r) 1 + pmin(1, pmax(0, (1.4 - days / t_r) / 0.45))
reserve_time <- function(pars) pars$storage_relaxation_offset * 365 * log(pars$a_st3 * pars$a_dG2)

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

nodes_of <- function(sch, k, half = FALSE) {
  S <- unlist(lapply(sch$panels, function(p) {
    n <- p$n * 2^k; if (half && n >= 2) n <- n / 2
    if (n < 2) return(p$lo)
    c(p$lo, approx(p$mass / tail(p$mass, 1), p$at, seq(0, 1, length.out = n + 1)[2:n], ties = "ordered")$y) }))
  sort(unique(round(S, 10)))
}
nested <- function(coarse, fine) all(round(coarse, 10) %in% round(fine, 10))

# As refine.R's, and `last` is the stand behind `run` (its J and elasticities,
# birth rate among them), so Newton can start from it without another run.
refine_schedule <- function(p, env, ctrl, scale = 1) {
  history <- list(); costs <- list(); level <- 0; q <- e <- unestimated <- sch <- last <- NULL
  fit <- function(status, error = NULL) list(
    answer = if (is.null(e)) q else q - e * eps_vec(names(q)), estimate = e,
    bound = if (is.null(e)) NULL else CORRECTED_SHARE * abs(e) + unestimated, run = q,
    last = last, schedule = sch, level = level, history = history, costs = do.call(rbind, costs),
    status = status, error = error)
  tryCatch({
    first <- stand_run(p, env, ctrl, seq(0, HORIZON, length.out = 100), gradient = FALSE, records = TRUE)
    costs$first <- first$cpu
    sch <- schedule_of(first, p$strategies[[1]]$pars, scale)
    S <- nodes_of(sch, 0); half <- nodes_of(sch, 0, half = TRUE); stopifnot(nested(half, S))
    x <- stand_run(p, env, ctrl, S); costs$level0 <- x$cpu; q <- judged(x); last <- x$stand[c("J", "elasticity")]
    r <- stand_run(p, env, ctrl, half, base = x); costs$level0_replay <- r$cpu
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
      level <- level + k; S <- finer; q <- qy; last <- y$stand[c("J", "elasticity")]
    }
  }, error = function(err) fit("failed", conditionMessage(err)))
}

refine_at <- function(b) {
  fit <- refine_schedule(stand(LMA0, b, 0), ENV, ctrl)
  S <- if (!is.null(fit$schedule)) nodes_of(fit$schedule, fit$level) else uniform_times(108)
  if (fit$status == "failed") {
    log_line("   refine failed: %s; holding %d nodes", fit$error, length(S))
  } else {
    log_line("   refine %s at level %d: %d nodes, %d passes, worst bound %.2f (%s)",
             fit$status, fit$level, length(S), length(fit$history), max(fit$bound),
             names(fit$bound)[which.max(fit$bound)])
  }
  print(fit$costs)
  list(status = fit$status, error = fit$error, level = fit$level, nodes = S, b = b,
       spells = if (!is.null(fit$schedule)) length(fit$schedule$spells$edges) else NA,
       worst_bound = if (is.null(fit$bound)) NA else max(fit$bound),
       worst = if (is.null(fit$bound)) NA else names(fit$bound)[which.max(fit$bound)],
       answer_lnJ = fit$answer[["lnJ"]], costs = fit$costs,
       last = fit$last)
}

## Newton in ln b on F = ln J - ln b, dF/d ln b = b J_b / J - 1, on fixed nodes.
RUNS <- new.env(); RUNS$n <- 0
resident_at <- function(b, times, lma = LMA0) {
  RUNS$n <- RUNS$n + 1
  scm <- run_scm(stand(lma, b, times), ENV, ctrl, record_trajectory = TRUE)
  g <- stand_gradient(scm, metrics = "1.offspring_production", traits = "1.birth_rate")
  J <- g$value[["1.offspring_production"]]
  list(scm = scm, b = b, J = J, F = log(J) - log(b),
       slope = b * g$gradient[1, 1] / J)
}

# Stops at |F| < tol, or where no step lowers |F|: the floor set by the adaptive
# steps' noise in J(b), accepted under `floor`. Under `floor` a step is not halved.
equilibrium <- function(b, times, start = NULL, lma = LMA0, tol = 1e-4, floor = 1e-3,
                        max_it = 10) {
  n0 <- RUNS$n
  at <- start
  if (is.null(at)) at <- resident_at(b, times, lma)
  trace <- list()
  done <- function(why) {
    log_line("   stopped: %s", why)
    list(scm = at$scm, b = at$b, J = at$J, F = at$F, slope = at$slope, runs = RUNS$n - n0,
         stop = why, trace = do.call(rbind, trace))
  }
  for (k in seq_len(max_it)) {
    secant <- if (length(trace)) {
      prev <- trace[[length(trace)]]
      (log(at$J) - log(prev$J)) / (log(at$b) - log(prev$b))
    } else NA
    trace[[k]] <- data.frame(it = k, b = at$b, J = at$J, F = at$F, slope = at$slope,
                             secant_slope = secant, from_refine = is.null(at$scm))
    log_line("   newton %2d  b = %.8g  F = %+.3e  d ln J/d ln b swept %.5f, secant %.5f",
             k, at$b, at$F, at$slope, secant)
    if (abs(at$F) < tol && !is.null(at$scm)) return(done("converged"))
    step <- -at$F / (at$slope - 1)
    step <- max(-1, min(1, step))
    better <- NULL
    for (halving in if (abs(at$F) < floor) 0 else 0:3) {
      try_at <- tryCatch(resident_at(at$b * exp(step / 2^halving), times, lma),
                         error = function(e) { log_line("   run failed: %s", conditionMessage(e)); NULL })
      if (!is.null(try_at) && abs(try_at$F) < abs(at$F)) { better <- try_at; break }
    }
    if (is.null(better)) {
      if (!is.null(at$scm) && abs(at$F) < floor) return(done("noise floor"))
      stop("no Newton step lowers |F| from ", signif(at$F, 3))
    }
    at <- better
  }
  if (abs(at$F) < floor) return(done("iteration cap"))
  stop("no equilibrium in ", max_it, " Newton steps; last F ", at$F)
}

## Invasions of a cache. Invaders enter only at the resident's introduction times.
invade <- function(cache, lma, times) {
  cache$run_mutant(stand(lma, 1, times))
  log(cache$net_reproduction_ratios)
}
selection <- function(cache, lma, times) {
  cache$run_mutant(stand(lma, 1, times))
  g <- stand_gradient(cache, metrics = "1.net_reproduction_ratio", traits = "1.lma",
                      hyperpar = TF24_hyperpar)
  if (any(stand_gradient_refused(g))) stop("sweep refused: ", format(g$refusal))
  R <- g$value[["1.net_reproduction_ratio"]]
  c(log_R = log(R), gradient = lma * g$gradient[1, 1] / R)
}

## The workflow.
t_all <- clock()
log_line("%s: TF24 at lma %.3g, %d years, tol %g / %g, step max %.4f y", climate, LMA0,
         LIFETIME, ctrl$ode_tol_rel, ctrl$ode_tol_abs, ctrl$ode_step_size_max)

log_line("0. Pilot forward at b = 1, 100 even introductions")
pilot <- timed("pilot", stand_run(stand(LMA0, 1, 0), ENV, ctrl, seq(0, HORIZON, length.out = 100),
                                  gradient = FALSE))
# ln b* from ln J(1) with the long-drought slope d ln J/d ln b = -0.76.
b0 <- if (is.null(pilot)) 1 else pilot$stand$J^(1 / 1.76)
out$pilot_J <- if (is.null(pilot)) NA else pilot$stand$J
out$b0 <- b0
log_line("   J(1) = %.6g, so b0 = %.6g", out$pilot_J, b0)
save_out()

log_line("1. Refine the schedule at b0")
ref <- timed("refine", refine_at(b0))
out$refine <- ref[setdiff(names(ref), "last")]
save_out()
if (is.null(ref)) stop("refine threw")
times <- ref$nodes

log_line("2. Resident equilibrium by Newton, the schedule held")
start <- if (!is.null(ref$last)) {
  J <- ref$last$J
  list(scm = NULL, b = b0, J = J, F = log(J) - log(b0), slope = ref$last$elasticity[["1.birth_rate"]])
}
eq <- timed("newton", equilibrium(b0, times, start))
out$rebuilt <- FALSE
if (!is.null(eq) && abs(log(eq$b / b0)) > log(2)) {
  log_line("   b* / b0 = %.3g: rebuild the schedule at b*", eq$b / b0)
  out$rebuilt <- TRUE
  out$newton_first <- list(b = eq$b, trace = eq$trace)
  ref <- timed("refine_again", refine_at(eq$b))
  out$refine_again <- ref[setdiff(names(ref), "last")]
  times <- ref$nodes
  eq <- timed("newton_again", equilibrium(eq$b, times))
}
if (is.null(eq)) { save_out(); stop("no equilibrium") }
out$equilibrium <- list(b = eq$b, J = eq$J, F = eq$F, slope = eq$slope, runs = eq$runs, stop = eq$stop, trace = eq$trace)
log_line("   b* = %.8g in %d runs; d ln J/d ln b = %.5f; d ln b*/d ln lma needs the lma column",
         eq$b, eq$runs, eq$slope)
save_out()
cache <- eq$scm

log_line("3. The invader at the resident's traits: ln R' and the selection gradient by the sweep")
sel <- timed("sweep", selection(cache, LMA0, times))
out$selection <- sel
if (!is.null(sel)) log_line("   ln R' = %+.3e; d ln R'/d ln lma = %+.5f", sel[["log_R"]], sel[["gradient"]])
save_out()

log_line("4. Landscape: invaders at lma x 0.5 ... 2, together")
factors <- c(0.5, 0.7, 0.85, 0.95, 1, 1.05, 1.2, 1.5, 2)
land <- timed("landscape", invade(cache, LMA0 * factors, times))
if (!is.null(land)) {
  out$landscape <- data.frame(factor = factors, lma = LMA0 * factors, log_R = land)
  print(out$landscape)
}
save_out()

log_line("5. Central differences of invasions")
hs <- c(1e-4, 1e-3)
cd <- timed("central_difference", {
  r <- invade(cache, LMA0 * exp(c(-hs, hs)), times)
  (r[3:4] - r[1:2]) / (2 * hs)
})
if (!is.null(cd)) {
  out$central_difference <- setNames(cd, paste0("h", hs))
  log_line("   h = %g: %+.5f;  h = %g: %+.5f;  sweep %+.5f", hs[1], cd[1], hs[2], cd[2],
           if (is.null(sel)) NA else sel[["gradient"]])
}
save_out()

if (HILL && !is.null(land) && !is.null(sel)) {
  log_line("6. One step uphill: the invader alone at its equilibrium, then the old resident invading it")
  up <- if (sel[["gradient"]] > 0) 1.05 else 0.95
  lma1 <- LMA0 * up
  out$hill <- list(lma1 = lma1, log_R_invader = land[factors == up])
  hill <- timed("hill_equilibrium", {
    # ln b*'s first-order move: the invader's ln R' against the resident's slope.
    b1 <- eq$b * exp(land[factors == up] / (1 - eq$slope))
    equilibrium(b1, times, lma = lma1)
  })
  if (!is.null(hill)) {
    back <- timed("back_invasion", invade(hill$scm, LMA0, times))
    out$hill$b1 <- hill$b
    out$hill$runs <- hill$runs
    out$hill$F <- hill$F
    out$hill$log_R_old <- back
    log_line("   invader alone: b* = %.6g in %d runs; the old resident's ln R' = %+.4f (%s)",
             hill$b, hill$runs, back, if (isTRUE(back < 0)) "replaced" else "coexist or return")
  }
  save_out()
}
out$times[["total"]] <- clock() - t_all
log_line("Total %.1f s", out$times[["total"]])
save_out()
