# Refine a TF24 node schedule until every quantity's error bound is under its eps
# (docs/design-refine-schedule.md). Source harness/long_drought.R first.
#
# refine_schedule(spec, dir, scale = 1), spec = list(regime, seed, trait, weight, lib), returns
# list(answer, estimate, bound, extrapolated, schedule, level, history, costs, status, error).
# Node times are nodes_of(fit$schedule, fit$level). Estimates and bounds are in eps.

RUN <- "/home/user/plant-dev/harness/schedule/refine_run.R"
SETTING <- c(TOL = "1e-4", ATOL = "1e-4", WEIGHT_SOIL = "10", WEIGHT_MAX = "100", HMAX = "15",
             SHARE = "0.1", SPLIT = "1")
HORIZON <- 107 * LIFETIME / 108

# A bound is |e| / MIN_ESTIMATE_RATIO + UNESTIMATED: the tolerance's bias, plus the short spells
# after a replay or the step changes between the runs of a doubled pair.
MIN_ESTIMATE_RATIO <- 0.82
UNESTIMATED_REPLAY <- 0.11 + 0.22
UNESTIMATED_PAIR <- 0.11 + 0.08
PREDICTED_BOUND_MAX <- 0.9
PASSES <- 4
MAX_LEVEL <- 4

# Quantities the bound's constants were not measured on: constant elasticities, and the
# rooting-depth kink.
EXCLUDED <- c("S_D", "a_f3", "recruitment_decay", "rooting_depth_max")
eps_tab <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps_of <- function(q) vapply(q, function(n) {
  if (n == "lnJ") return(0.025)
  e <- eps_tab$eps[eps_tab$role == "resident" & eps_tab$trait == n & eps_tab$unit != "curvature in lma"]
  max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE) }, 0)
quantities <- function(x) {
  if (!is.null(x$stand$refusal)) stop("gradient refused: ", x$stand$refusal)
  e <- unname(x$stand$elasticity); names(e) <- sub("^1\\.", "", names(x$stand$elasticity))
  q <- c(lnJ = log(x$stand$J), e[!names(e) %in% EXCLUDED])
  if (any(!is.finite(q))) stop("non-finite quantities: ", paste(names(q)[!is.finite(q)], collapse = ", "))
  q
}

# One run, reused from disk only when the same request (times, setting, base run) made it.
scm_run <- function(spec, dir, name, times, base = NULL, forward = FALSE, first = FALSE) {
  out <- file.path(dir, paste0(name, ".rds")); tf <- file.path(dir, paste0(name, "_times.rds"))
  env <- c(SETTING, REGIME = spec$regime, SEED = spec$seed, TRAIT_REL = spec$trait, WEIGHT = spec$weight,
           LIB = spec$lib, PIN = if (is.null(base)) "" else base, FORWARD = if (forward) "1" else "",
           FIRST = if (first) "1" else "")
  request <- list(times = times, env = env)
  rf <- file.path(dir, paste0(name, "_request.rds"))
  if (file.exists(out) && file.exists(rf) && identical(readRDS(rf), request)) {
    x <- readRDS(out); if (!is.null(x$finished)) return(x) }
  unlink(out); saveRDS(times, tf); saveRDS(request, rf)
  log <- file.path(dir, paste0(name, ".log"))
  run_env <- c(env, TIMES = tf, OUT = out)
  status <- system2("Rscript", RUN, env = paste0(names(run_env), "=", run_env), stdout = log, stderr = log)
  if (status != 0 || !file.exists(out) || is.null(readRDS(out)$finished)) stop("run ", name, " failed (", log, ")")
  readRDS(out)
}

# Spell edges from the first run's establishment rate, and the ages t50 and t90, when half and
# 90% of J have been produced. A record that never closes is one spell to the horizon.
spells_of <- function(first) {
  er <- first$stand$establishment; open <- er$rate > 0.01
  r <- rle(open); e <- cumsum(r$lengths); b <- er$end[e][-length(e)]; ending <- open[e][-length(e)]
  k <- b > 0 & b < HORIZON
  remaining <- first$stand$remaining
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
schedule_of <- function(first, scale = 1) {
  sp <- spells_of(first); h <- spacing_of(first, sp); t_r <- reserve_time(first$pars)
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

refine_schedule <- function(spec, dir, scale = 1) {
  stopifnot(all(c("regime", "seed", "trait", "weight", "lib") %in% names(spec)))
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  history <- list(); costs <- list(); level <- 0; q <- e <- unestimated <- sch <- NULL
  cost <- function(x) c(forward = x$stand$cpu, sweep = if (is.null(x$sweep_cpu)) 0 else x$sweep_cpu)
  fit <- function(status, error = NULL) list(
    answer = q, estimate = e, bound = if (is.null(e)) NULL else abs(e) / MIN_ESTIMATE_RATIO + unestimated,
    extrapolated = if (is.null(e)) NULL else q - e * eps_of(names(q)), schedule = sch, level = level,
    history = history, costs = do.call(rbind, costs), status = status, error = error)
  tryCatch({
    first <- scm_run(spec, dir, "first", seq(0, HORIZON, length.out = 100), forward = TRUE, first = TRUE)
    costs$first <- cost(first)
    sch <- schedule_of(first, scale)
    S <- nodes_of(sch, 0); half <- nodes_of(sch, 0, half = TRUE); stopifnot(nested(half, S))
    x <- scm_run(spec, dir, "level0", S); costs$level0 <- cost(x); q <- quantities(x)
    r <- scm_run(spec, dir, "level0_replay", half, base = file.path(dir, "level0.rds")); costs$level0_replay <- cost(r)
    e <- (quantities(r)[names(q)] - q) / 3 / eps_of(names(q)); unestimated <- UNESTIMATED_REPLAY
    repeat {
      bound <- abs(e) / MIN_ESTIMATE_RATIO + unestimated
      history[[length(history) + 1]] <- list(level = level, nodes = length(S), answer = q, estimate = e,
                                             worst = names(q)[which.max(bound)], worst_bound = max(bound))
      if (all(bound < 1)) return(fit("converged"))
      if (length(history) == PASSES || level == MAX_LEVEL) return(fit("unconverged"))
      k <- 1
      while (max(abs(e) / 4^k / MIN_ESTIMATE_RATIO + UNESTIMATED_PAIR) > PREDICTED_BOUND_MAX && level + k < MAX_LEVEL) k <- k + 1
      finer <- nodes_of(sch, level + k); stopifnot(nested(S, finer))
      y <- scm_run(spec, dir, paste0("level", level + k), finer); costs[[paste0("level", level + k)]] <- cost(y)
      qy <- quantities(y)[names(q)]
      e <- (q - qy) / (4^k - 1) / eps_of(names(q)); unestimated <- UNESTIMATED_PAIR
      level <- level + k; S <- finer; q <- qy
    }
  }, error = function(err) fit("failed", conditionMessage(err)))
}
