# Refine a TF24 node schedule from E6 until every quantity's estimated error is under a
# target, each run nested in the one before and measuring the region it refined.
#
# refine_schedule(case, start = "E6", target = 1, ...) where case is a list with
#   S0, S1   E6's committed and check schedules (birth dates, years)
#   edges    the pilot's edges before 25: data.frame(b, opening)
#   b1       the first closing edge
#   eps      each quantity's eps, named as the run's quantities
#   run      run(S, map) -> list(q, rows, times, map): q the quantities, times the accepted
#            step times, map (when map = TRUE) ln J's error by region F, I1, I2, I3, L from
#            the run's node-drop map, in eps of ln J
# or the name of a case that case_of_refine(name) turns into that list.
# Returns the final schedule, its answer and per-quantity estimate (in eps), the region
# table and the run history.
#
# Known weak spots, each a silent misread (refine/notes.md):
# - The estimate is E1 minus everything moved since S1, so E1's own misread stays in it in
#   absolute terms and grows relative to a shrinking error (read x2.1-2.3 at the end).
# - Regions are ranked by ln J's map alone; the elasticity error can sit in a region it
#   ranks low (the founders on episodic-lma, refined last).
# - E6's pair is off the square law at S1's level on the dry records (reads 0.58-0.63,
#   cos down to -0.17), so a target of eps/2 or finer can stop at S1 on a wrong estimate.

REGIONS <- c("F", "I1", "I2", "I3", "O", "C", "L")
MAP_REGIONS <- c("F", "I1", "I2", "I3", "L")

# Each interval's region. Strip zones are the `zone` days inside each edge before 25; an
# interval spanning an edge reads the strips across the gap and is refined only through them.
interval_regions <- function(S, edges, b1, zone = 7.5 / 365, late = 25, tol = 1e-9) {
  lo <- head(S, -1); hi <- S[-1]; mid <- (lo + hi) / 2
  e <- edges[order(edges$b), ]
  vapply(seq_along(lo), function(i) {
    if (mid[i] >= late) return("L")
    if (any(e$b > lo[i] + tol & e$b < hi[i] - tol)) return("gap")
    k <- which(e$b < mid[i]); if (length(k)) k <- max(k)
    if (length(k) && !e$opening[k]) return("gap")
    nxt <- e$b[e$b > mid[i]]
    if (length(k) && hi[i] <= e$b[k] + zone + tol) return("O")
    if (length(nxt) && lo[i] >= min(nxt) - zone - tol) return("C")
    if (mid[i] < b1) "F" else if (mid[i] < 10) "I1" else if (mid[i] < 17) "I2" else "I3"
  }, "")
}

# The nodes one refinement of region g adds: midpoints of g's intervals, or for a strip
# region a node halfway between each edge and its nearest node on the spell side.
refine_nodes <- function(S, g, edges, b1, min_half = 0.5 / 365) {
  if (!g %in% c("O", "C")) {
    i <- which(interval_regions(S, edges, b1) == g)
    return((S[i] + S[i + 1]) / 2)
  }
  e <- edges[edges$opening == (g == "O"), ]
  add <- vapply(e$b, function(b) {
    side <- if (g == "O") S[S > b + 1e-9] else S[S < b - 1e-9]
    if (!length(side)) return(NA_real_)
    n <- if (g == "O") min(side) else max(side)
    half <- (n - b) / 2
    if (abs(half) < min_half) NA_real_ else b + half
  }, 0)
  add[!is.na(add)]
}

# Rows a set of new nodes adds, read off the current run's accepted steps.
rows_added <- function(add, times) {
  t0 <- head(times, -1)
  sum(vapply(add, function(b) sum(t0 >= b - 1e-12), 0))
}

rms <- function(x) sqrt(mean(x^2))

refine_schedule <- function(case, start = "E6", target = 1, max_runs = 10, r = 1.6,
                            noise = 0.024, flag_ratio = 0.5, rho_max = 0.8) {
  stopifnot(start == "E6")
  if (is.character(case)) case <- case_of_refine(case)
  eps <- case$eps
  qe <- function(x) x$q[names(eps)] / eps
  history <- list()
  log_run <- function(x, S, region, est) {
    history[[length(history) + 1]] <<- data.frame(run = length(history) + 1, region = region,
      nodes = length(S), rows = x$rows, est_max = if (is.null(est)) NA else max(abs(est)),
      est_q = if (is.null(est)) NA else names(eps)[which.max(abs(est))])
  }
  x0 <- case$run(case$S0, map = FALSE); log_run(x0, case$S0, "S0", NULL)
  x1 <- case$run(case$S1, map = FALSE)
  E1 <- (qe(x0) - qe(x1)) / (r^2 - 1)
  log_run(x1, case$S1, "S1", E1)
  regions <- data.frame(region = REGIONS, share = NA, refined = 0, flagged = FALSE,
                        pending = FALSE, rows_added = 0)
  e_S1 <- list(); moves <- list(); rem <- list()
  done <- function(S, x, est) list(schedule = S, answer = x$q[names(eps)], estimate = est,
    target = target, regions = regions, e_S1 = e_S1, moves = moves, remainder = rem,
    history = do.call(rbind, history), E1 = E1)
  if (all(abs(E1) < target)) return(done(case$S1, x1, E1))

  # The S1 map's |ln J| per region; the strips share the pair's ln J remainder.
  x1 <- case$run(case$S1, map = TRUE)
  m1 <- x1$map[MAP_REGIONS]
  strip <- abs(E1[["lnJ"]] - sum(m1))
  a <- c(abs(m1), O = strip / 2, C = strip / 2)[REGIONS]
  regions$share <- a / sum(a)
  S <- case$S1; x <- x1; est <- E1
  while (length(history) < max_runs) {
    adds <- lapply(setNames(REGIONS, REGIONS), function(g) refine_nodes(S, g, case$edges, case$b1))
    cost <- vapply(adds, rows_added, 0, times = x$times)
    err <- vapply(REGIONS, function(g) if (is.null(rem[[g]])) rms(E1) * regions$share[regions$region == g]
                                       else rms(rem[[g]]), 0)
    score <- ifelse(cost > 0, 0.75 * err / pmax(cost, 1), -Inf)
    pend <- regions$region[regions$pending & cost[regions$region] > 0]
    g <- if (length(pend)) pend[1] else REGIONS[which.max(score)]
    if (!is.finite(score[[g]]) && !length(pend)) break
    S_new <- sort(unique(round(c(S, adds[[g]]), 10)))
    x_new <- case$run(S_new, map = TRUE)
    m <- qe(x) - qe(x_new)
    k <- regions$region == g
    moves[[g]] <- c(moves[[g]], list(m))
    regions$refined[k] <- regions$refined[k] + 1
    regions$rows_added[k] <- regions$rows_added[k] + x_new$rows - x$rows
    rho <- 1 / 4
    if (length(moves[[g]]) > 1) {
      # A second move over half the first, on the quantities the first put over the
      # noise, marks the region as not asymptotic: its own ratio sets the remainder.
      mv <- moves[[g]]; m_a <- mv[[length(mv) - 1]]; m_b <- mv[[length(mv)]]
      big <- abs(m_a) > 3 * noise
      ratio <- if (any(big)) rms(m_b[big]) / rms(m_a[big]) else 0
      was_pending <- regions$pending[k]
      if (ratio > flag_ratio) {
        rho <- min(max(sum(m_b[big] * m_a[big]) / sum(m_a[big]^2), 1 / 4), rho_max)
        regions$flagged[k] <- TRUE
      }
      regions$pending[k] <- ratio > flag_ratio && !was_pending
    }
    rem[[g]] <- m * rho / (1 - rho)
    # Order 2 at the first move: the region's S1 error is 4/3 of it. A region shown not
    # to be asymptotic re-reads its S1 error as everything it moved plus its remainder.
    if (length(moves[[g]]) == 1) e_S1[[g]] <- m * 4 / 3
    if (regions$flagged[k]) e_S1[[g]] <- Reduce(`+`, moves[[g]]) + rem[[g]]
    est <- E1 - Reduce(`+`, e_S1, 0 * E1) + Reduce(`+`, rem, 0 * E1)
    S <- S_new; x <- x_new
    log_run(x, S, g, est)
    if (all(abs(est) < target) && !any(regions$pending)) break
  }
  done(S, x, est)
}
