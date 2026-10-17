# The schedule loop: pick the node spacing for one case from a few gradient runs.
#
# schedule_loop(run, eps, sel_scale, ...) where run(s) returns the gradient run on the
# layout at spacing scale s (s = 1 is the start) as a list with q (the quantities, named as
# eps) and rows, and optionally map (ln J's error from the run's own node-drop map, in eps
# of ln J). Steps:
#   1. run s = 1; the elasticity scale S_el = rms(elasticity / eps) times sel_scale predicts
#      its worst error; under the target, run s * 1.6 next, otherwise s / 1.6;
#   2. the pair's estimate, order 2 in the spacing ratio R: the finer member's error is
#      (Q_coarse - Q_fine) / (R^2 - 1), the coarser member's R^2 times that;
#   3. answer with the coarsest member whose every |estimate| is under target = 1 - reserve,
#      whose amplified jitter (jitter * R^2 / (R^2 - 1) for the coarser member,
#      / (R^2 - 1) for the finer) is under 1/3, and whose map, where given, agrees with the
#      pair's ln J estimate within map_k standard deviations;
#   4. otherwise one more run: at the spacing the finest pair's constant says meets
#      0.9 * target (between 1.25 and 2 times finer), or 1.6 times finer when a map
#      disagreed, rounded to 0.001; pair it with the finest run so far and return to 3.
#      At most kmax runs; at the cap the finest run is the answer, marked.
# Returns the final spacing, the answer, its estimate, the diagnostics and every run.
schedule_loop <- function(run, eps, sel_scale, reserve = 0.15, r = 1.6, kmax = 4,
                          jitter = 0.09, map_sd = 0.02, run_sd = 0.02, map_k = 3) {
  target <- 1 - reserve
  runs <- list()
  get <- function(s) {
    key <- sprintf("%.6f", s)
    if (is.null(runs[[key]])) {
      x <- run(s)
      runs[[key]] <<- list(s = s, q = x$q[names(eps)], rows = x$rows, map = x$map)
    }
    runs[[key]]
  }
  start <- get(1)
  el <- setdiff(names(eps), "lnJ")
  sel <- sqrt(mean((start$q[el] / eps[el])^2))
  predicted <- sel_scale * sel
  second <- get(if (predicted < target) r else 1 / r)
  history <- list()
  judge <- function(a, b) {
    R <- a$s / b$s
    est_b <- (a$q - b$q) / eps / (R^2 - 1)
    members <- list(list(run = a, est = R^2 * est_b, amp = R^2 / (R^2 - 1)),
                    list(run = b, est = est_b, amp = 1 / (R^2 - 1)))
    for (m in members) {
      m$noise_ok <- jitter * m$amp < 1 / 3
      m$under <- max(abs(m$est)) < target
      m$map_gap <- if (is.null(m$run$map)) NA else m$run$map - m$est[["lnJ"]]
      m$map_lim <- map_k * sqrt(map_sd^2 + 2 * (run_sd * m$amp)^2)
      m$map_ok <- is.na(m$map_gap) || abs(m$map_gap) <= m$map_lim
      history[[length(history) + 1]] <<- data.frame(s = m$run$s, pair = sprintf("%.3f/%.3f", a$s, b$s),
        est_max = max(abs(m$est)), est_lnJ = m$est[["lnJ"]], map = if (is.null(m$run$map)) NA else m$run$map,
        map_gap = m$map_gap, map_lim = m$map_lim, under = m$under, noise_ok = m$noise_ok, map_ok = m$map_ok)
      if (m$under && m$noise_ok && m$map_ok) return(list(done = TRUE, m = m, R = R))
    }
    list(done = FALSE, est_b = est_b, map_hit = !all(vapply(members, function(m) m$map_ok, TRUE)))
  }
  pair <- if (second$s > start$s) list(second, start) else list(start, second)
  repeat {
    j <- judge(pair[[1]], pair[[2]])
    if (j$done) break
    fine <- pair[[2]]
    if (length(runs) >= kmax) {
      j <- list(m = list(run = fine, est = j$est_b, amp = NA), R = pair[[1]]$s / fine$s, cap = TRUE)
      break
    }
    s_next <- if (j$map_hit) fine$s / r else fine$s * sqrt(0.9 * target / max(abs(j$est_b)))
    s_next <- round(min(max(s_next, fine$s / 2), fine$s / 1.25), 3)
    pair <- list(fine, get(s_next))
  }
  final <- j$m$run
  list(s = final$s, q = final$q, est = j$m$est, R = j$R, cap = isTRUE(j$cap),
       predicted = predicted, sel = sel, target = target,
       history = do.call(rbind, history),
       runs = do.call(rbind, lapply(runs, function(x) data.frame(s = x$s, rows = x$rows))))
}

# Route B: map-guided refinement from a coarse start. Each region g (founders, interior eras,
# late) has its own background scale s_g; edge strips stay on fixed nodes.
# allocation_loop(run, eps, sel_scale, regions, ...) where run(sv), sv a named scale per
# region, returns q, rows, map (ln J's error by region from the run's own node-drop map, eps of
# ln J, plus "all") and region_rows (the rows of each region's nodes). Steps:
#   1. run every region at r; each run's map gives k_g = |map_g| / s_g^2, so a layout's error
#      proxy is P(sv) = sum k_g s_g^2;
#   2. the next layout minimises the rows sum R_g s_g' / s_g subject to P = P_next: equal
#      marginal error per row, s_g proportional to (R_g s_g / k_g)^(1/3), within [smin, r],
#      rounded to 0.001.
#      P_next is P_1 times the elasticity scale's predicted shrink to 0.9 * target (between
#      1/4 and 1/r^2) after the first run, and after a pair the spacing the pair's constant
#      says meets 0.9 * target (between 1/4 and 1/1.5 of the finer member's P);
#   3. a pair's estimate, k from the finer member's map: finer member d P_b / (P_a - P_b),
#      coarser d P_a / (P_a - P_b); the answer and the map flag as in schedule_loop.
# At most kmax runs; at the cap the finest run is the answer, marked.
allocation_loop <- function(run, eps, sel_scale, regions, reserve = 0.15, r = 1.6, kmax = 5,
                            smin = 0.3, floor = 0.005, jitter = 0.09, map_sd = 0.02,
                            run_sd = 0.02, map_k = 3) {
  target <- 1 - reserve
  runs <- list()
  get <- function(sv) {
    x <- run(sv)
    k <- pmax(abs(x$map[regions]), floor) / sv[regions]^2
    runs[[length(runs) + 1]] <<- list(sv = sv, q = x$q[names(eps)], rows = x$rows, map = x$map[["all"]],
                                       k = k, R = x$region_rows[regions])
    runs[[length(runs)]]
  }
  P <- function(k, sv) sum(k * sv[regions]^2)
  allocate <- function(x, p_next) {
    w <- (x$R * x$sv[regions] / x$k)^(1 / 3)
    p_next <- min(max(p_next, P(x$k, x$sv * 0 + smin) * (1 + 1e-9)), P(x$k, x$sv * 0 + r) * (1 - 1e-9))
    f <- function(l) P(x$k, pmin(pmax(l * w, smin), r)) - p_next
    l <- uniroot(f, c(1e-9, 1e9) / max(w), tol = 1e-12)$root
    setNames(round(pmin(pmax(l * w, smin), r), 3), regions)
  }
  first <- get(setNames(rep(r, length(regions)), regions))
  el <- setdiff(names(eps), "lnJ")
  sel <- sqrt(mean((first$q[el] / eps[el])^2))
  predicted <- sel_scale * sel * r^2
  rho <- min(max(0.9 * target / predicted, 1 / 4), 1 / r^2)
  pair <- list(first, get(allocate(first, rho * P(first$k, first$sv))))
  history <- list()
  repeat {
    a <- pair[[1]]; b <- pair[[2]]; pa <- P(b$k, a$sv); pb <- P(b$k, b$sv)
    d <- (a$q - b$q) / eps
    members <- list(list(run = a, est = d * pa / (pa - pb), amp = pa / (pa - pb)),
                    list(run = b, est = d * pb / (pa - pb), amp = pb / (pa - pb)))
    members <- lapply(members, function(m) {
      m$map_gap <- m$run$map - m$est[["lnJ"]]
      m$map_lim <- map_k * sqrt(map_sd^2 + 2 * (run_sd * m$amp)^2)
      m$ok <- c(under = max(abs(m$est)) < target, noise = jitter * m$amp < 1 / 3, map = abs(m$map_gap) <= m$map_lim)
      m })
    for (m in members) history[[length(history) + 1]] <- data.frame(iter = match(list(m$run), runs), rows = m$run$rows,
      P_ratio = pb / pa, est_max = max(abs(m$est)), est_lnJ = m$est[["lnJ"]], map = m$run$map, map_gap = m$map_gap,
      map_lim = m$map_lim, under = m$ok[["under"]], noise_ok = m$ok[["noise"]], map_ok = m$ok[["map"]])
    ok <- which(vapply(members, function(m) all(m$ok), TRUE))
    done <- if (length(ok)) members[[ok[1]]]
    if (!is.null(done)) break
    if (length(runs) >= kmax) { done <- members[[2]]; done$cap <- TRUE; break }
    map_hit <- !all(vapply(members, function(m) m$ok[["map"]], TRUE))
    p_next <- if (map_hit) pb / r^2 else min(max(0.9 * target / max(abs(d / (pa - pb))), pb / 4), pb / 1.5)
    pair <- list(b, get(allocate(b, p_next)))
  }
  final <- done$run
  list(sv = final$sv, q = final$q, est = done$est, cap = isTRUE(done$cap), iter = match(list(final), runs),
       predicted = predicted, sel = sel, target = target, history = do.call(rbind, history),
       runs = do.call(rbind, lapply(seq_along(runs), function(i) data.frame(iter = i, rows = runs[[i]]$rows,
         t(runs[[i]]$sv[regions]), map = runs[[i]]$map))),
       q_runs = lapply(runs, `[[`, "q"))
}
