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
