# Helpers for the field probe: the finer node in each coarse panel, its
# establishment weight from a run's creation record, and the per-node data.

# For each panel [x_p, x_{p+1}] of `coarse`, the node of `fine` strictly inside
# it (NaN where none). A nested schedule puts at most one there.
fine_at <- function(coarse, fine) {
  x <- sort(coarse); f <- setdiff(round(sort(fine), 10), round(x, 10))
  at <- rep(NaN, length(x) - 1)
  j <- findInterval(f, x)
  stopifnot(!anyDuplicated(j), all(j >= 1 & j < length(x)))
  at[j] <- f
  at
}

# The finer node's establishment weight: the step-averaged creation probability
# integrated against its hat (x_p, at_p, x_{p+1}), panel by panel.
fine_weight <- function(creation, coarse, at) {
  x <- sort(coarse)
  hat_integral <- function(a, m, b, lo, hi) {
    # integral over [lo, hi] of the hat with feet a, b and peak m
    up <- function(s, e) { s <- max(s, a); e <- min(e, m); if (e <= s) 0 else ((e - a)^2 - (s - a)^2) / (2 * (m - a)) }
    dn <- function(s, e) { s <- max(s, m); e <- min(e, b); if (e <= s) 0 else ((b - s)^2 - (b - e)^2) / (2 * (b - m)) }
    up(lo, hi) + dn(lo, hi)
  }
  vapply(seq_along(at), function(p) {
    if (!is.finite(at[p])) return(NaN)
    a <- x[p]; b <- x[p + 1]; m <- at[p]
    i <- which(creation$end > a & creation$start < b)
    sum(creation$rate[i] * vapply(i, function(k) hat_integral(a, m, b, creation$start[k], creation$end[k]), 0))
  }, 0)
}

per_node <- function(scm) {
  sp <- scm$patch$species[[1]]
  state <- matrix(sp$ode_state, ncol = sp$size, dimnames = list(sp$new_node$ode_names))
  list(birth = sp$node_times, establishment = sp$establishment_weights,
       nrr = sp$net_reproduction_ratio_by_node, height = state["height", ],
       mortality = state["mortality", ])
}

creation_record <- function(scm) {
  rows <- scm$store_trajectory()
  sp <- scm$patch$species[[1]]
  per <- length(sp$ode_state) / sp$size
  at <- which(sp$new_node$ode_names == "interval_establishment")
  len <- lengths(lapply(rows, `[[`, "state"))
  held <- (len - (tail(len, 1) - per * sp$size)) / per
  t <- vapply(rows, `[[`, 0, "time")
  I <- vapply(seq_along(rows), function(i)
    if (held[i] > 0) rows[[i]]$state[per * (held[i] - 1) + at] else NA_real_, 0)
  i <- which(diff(held) == 0 & diff(t) > 0)
  list(start = t[i], end = t[i + 1], rate = (I[i + 1] - I[i]) / (t[i + 1] - t[i]))
}

# The environment's own state (soil water by layer and the rest) at every
# accepted step: the trailing entries of each recorded state, as many as the
# empty patch's first row holds.
env_record <- function(scm) {
  rows <- scm$store_trajectory()
  n_env <- length(rows[[1]]$state)
  keep <- !vapply(rows, function(r) isTRUE(r$introduction), TRUE)
  t <- vapply(rows[keep], `[[`, 0, "time")
  st <- t(vapply(rows[keep], function(r) tail(r$state, n_env), numeric(n_env)))
  list(time = t, state = st)
}
