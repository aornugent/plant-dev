# Refine a TF24 node schedule until every quantity's error bound is under its eps
# (docs/design-refine-schedule.md). Every full run is a candidate answer: the first pass is
# estimated by a replay of itself with every other interior node removed, and each later
# pass doubles every count, so the run before it is its estimate.
#
# refine_schedule(spec, dir, scale = 1) where spec is list(regime, seed, trait, weight)
# returns list(answer, estimate, bound, extrapolated, schedule, history, status).
# Quantities are ln J and the elasticities, in their own units; estimate and bound in eps.

RUN <- "/home/user/plant-dev/harness/schedule/refine_run.R"
SETTING <- c(TOL = "1e-4", ATOL = "1e-4", WEIGHT_SOIL = "10", WEIGHT_MAX = "100", HMAX = "15",
             SHARE = "0.1", SPLIT = "1")
HORIZON <- 107 * 40 / 108

# The bound |e| / READ + UNSEEN. READ is the lowest measured ratio of the replay's estimate
# to the true error; UNSEEN is what the estimate cannot contain: the tolerance's bias, and
# spells too short to hold two intervals on the replay (a doubled pair estimates those, but
# carries step noise instead).
READ <- 0.82
UNSEEN_REPLAY <- 0.11 + 0.22
UNSEEN_PAIR <- 0.11 + 0.05
MARGIN <- 0.9
PASSES <- 4

eps_tab <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
eps_of <- function(q) vapply(q, function(n) {
  if (n == "lnJ") return(0.025)
  e <- eps_tab$eps[eps_tab$role == "resident" & eps_tab$trait == n & eps_tab$unit != "curvature in lma"]
  max(if (length(e)) e[1] else NA, 0.01, na.rm = TRUE) }, 0)
quantities <- function(x) {
  e <- unname(x$stand$elasticity); names(e) <- sub("^1\\.", "", names(x$stand$elasticity))
  c(lnJ = log(x$stand$J), e[!names(e) %in% c("S_D", "a_f3", "recruitment_decay")])
}

# One run, kept on disk under its name so an interrupted refinement resumes.
scm_run <- function(spec, dir, name, times, pin = NULL, forward = FALSE, first = FALSE) {
  out <- file.path(dir, paste0(name, ".rds"))
  if (file.exists(out)) { x <- readRDS(out); if (!is.null(x$finished)) return(x) }
  tf <- file.path(dir, paste0(name, "_times.rds")); saveRDS(times, tf)
  env <- c(SETTING, REGIME = spec$regime, SEED = spec$seed, TRAIT_REL = spec$trait, WEIGHT = spec$weight,
           LIB = spec$lib, TIMES = tf, OUT = out, PIN = if (is.null(pin)) "" else pin,
           FORWARD = if (forward) "1" else "", FIRST = if (first) "1" else "")
  status <- system2("Rscript", RUN, env = paste0(names(env), "=", env),
                    stdout = file.path(dir, paste0(name, ".log")), stderr = file.path(dir, paste0(name, ".log")))
  if (status != 0 || !file.exists(out) || is.null(readRDS(out)$finished)) stop("run ", name, " failed")
  readRDS(out)
}

# Spell openings and ends from the first run's establishment rate, and T(t)'s ages: t50 and
# t90, when half and 90% of J have been produced.
spells_of <- function(first) {
  er <- first$stand$establishment; open <- er$rate > 0.01
  r <- rle(open); e <- cumsum(r$lengths); b <- er$end[e][-length(e)]; ending <- open[e][-length(e)]
  k <- b > 0 & b < HORIZON
  rm <- first$stand$remaining; when <- function(s) rm$time[which(rm$share <= s)[1]]
  list(edges = b[k], ending = ending[k], b1 = b[k][ending[k]][1], t50 = when(0.5), t90 = when(0.1),
       shut = approxfun(c(er$start, tail(er$end, 1)), c(!open, !tail(open, 1)), method = "constant", rule = 2))
}

# Node spacing from the offspring curve: fine over the first cohorts' steep fall, a cap of
# 100 d until t50 and 280 d after, wider where offspring are far below the spells' median.
spacing_of <- function(first, sp) {
  n <- first$stand$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  early <- n$birth < sp$b1; y <- log(pmax(n$nrr[early], 1e-30)); fall <- log(n$nrr[1] / 10)
  i <- which(y < fall)[1]
  l1 <- if (is.na(i)) sp$b1 else if (i == 1) 0 else
    n$birth[i - 1] + (y[i - 1] - fall) / (y[i - 1] - y[i]) * (n$birth[i] - n$birth[i - 1])
  ref <- median(log(pmax(n$nrr[n$birth > sp$b1 & n$birth < sp$t50], 1e-300)))
  function(b) {
    cap <- if (b < sp$b1) sp$b1 / 12 else if (b < sp$t50) 100 / 365 else 280 / 365
    min(cap, if (b < sp$b1) { if (b < l1) sp$b1 / 24 else sp$b1 / 12 } else 90 / 365 * max(1, exp(0.2 * (ref - lf(b))))) }
}

# Twice the density over the t_r before each spell end, falling to 1 by 1.4 t_r. t_r is the
# time a newborn's reserves take to run down: o ln(a_st3 a_dG2).
grade <- function(days, t_r) 1 + pmin(1, pmax(0, (1.4 - days / t_r) / 0.45))
reserve_time <- function(pars) pars$storage_relaxation_offset * 365 * log(pars$a_st3 * pars$a_dG2)

# The schedule: breakpoints at 0, every edge up to t90 and the horizon; between them an
# interval count per spell (one where the density holds at most one, otherwise even plus
# two) and nodes at equal shares of the density. Level k multiplies every count by 2^k, so
# each level's nodes contain the level below's.
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
    list(lo = br[i], hi = br[i + 1], n = n, mass = c(0, cumsum(rho[k] * dg)), at = c(br[i], gm[k] + dg / 2)) })
  list(breaks = br, panels = panels, spells = sp, t_r = t_r, scale = scale)
}

# Node times at level k; `half` keeps every other interior node of each spell that holds two
# or more intervals, the replay's schedule.
nodes_of <- function(sch, k, half = FALSE) {
  S <- unlist(lapply(sch$panels, function(p) {
    n <- p$n * 2^k; if (half && n >= 2) n <- n / 2
    if (n < 2) return(p$lo)
    c(p$lo, approx(p$mass / tail(p$mass, 1), p$at, seq(0, 1, length.out = n + 1)[2:n], ties = "ordered")$y) }))
  sort(unique(round(S, 10)))
}

refine_schedule <- function(spec, dir, scale = 1) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  pars <- scm_base_parameters("TF24")$strategy_default$pars
  for (kv in strsplit(strsplit(spec$trait, ",")[[1]], "=")) pars[[kv[1]]] <- pars[[kv[1]]] * (1 + as.numeric(kv[2]))
  first <- scm_run(spec, dir, "first", seq(0, HORIZON, length.out = 100), forward = TRUE, first = TRUE)
  sch <- schedule_of(first, pars, scale)
  history <- list(); cost <- function(x) c(forward = x$stand$cpu, sweep = if (is.null(x$sweep_cpu)) 0 else x$sweep_cpu)
  level <- 0; x <- scm_run(spec, dir, "level0", nodes_of(sch, 0))
  q <- quantities(x); eps <- eps_of(names(q))
  r <- scm_run(spec, dir, "level0_replay", nodes_of(sch, 0, half = TRUE), pin = file.path(dir, "level0.rds"))
  e <- (quantities(r)[names(q)] - q) / 3 / eps; unseen <- UNSEEN_REPLAY
  costs <- list(first = cost(first), level0 = cost(x), level0_replay = cost(r))
  status <- "converged"
  repeat {
    bound <- abs(e) / READ + unseen
    history[[length(history) + 1]] <- list(level = level, nodes = length(x$node_times), worst = names(q)[which.max(bound)],
                                           bound = max(bound), estimate = e, answer = q)
    if (all(bound < 1)) break
    if (length(history) == PASSES) { status <- "unconverged"; break }
    k <- 1; while (max(abs(e) / 4^k / READ + UNSEEN_PAIR) > MARGIN && k < 3) k <- k + 1
    level <- level + k; nm <- paste0("level", level)
    y <- scm_run(spec, dir, nm, nodes_of(sch, level))
    qy <- quantities(y)[names(q)]
    e <- (q - qy) / (4^k - 1) / eps; unseen <- UNSEEN_PAIR
    x <- y; q <- qy; costs[[nm]] <- cost(y)
  }
  list(answer = q, estimate = e, bound = abs(e) / READ + unseen, extrapolated = q - e * eps,
       schedule = list(breaks = sch$breaks, counts = vapply(sch$panels, `[[`, 0, "n") * 2^level,
                       nodes = x$node_times, t_r = sch$t_r, ages = unlist(sch$spells[c("b1", "t50", "t90")])),
       history = history, costs = do.call(rbind, costs), status = status)
}
