# Exact emulation of an invader walk on a subset of the run's introductions,
# from one full walk's per-node data (walks.R): plant's birth-date quadrature
# (species.h for_each_establishment_weight) over the merged intervals, with each
# kept member's fecundity unchanged since members see only the recorded field.
T_END <- 40

fecundity_of <- function(nd) nd$nrr * nd$pd * nd$S_D * nd$br

# Establishment weights of the kept nodes (indices into the full schedule, the
# first always kept). A merged interval a..c: E = sum E_k, M = sum (M_k + (b_k -
# b_a) E_k); the last kept node's interval runs to the run's end, where the
# boundary node's share is dropped, as plant drops it.
weights_of <- function(nd, keep) {
  b <- nd$birth; E <- nd$E; M <- nd$M; n <- length(b)
  keep <- sort(unique(keep))
  stopifnot(keep[1] == 1)
  w <- numeric(length(keep)); from_prev <- 0
  for (i in seq_along(keep)) {
    a <- keep[i]; c_ <- if (i < length(keep)) keep[i + 1] else n + 1
    k <- a:(c_ - 1)
    Ep <- sum(E[k]); Mp <- sum(M[k] + (b[k] - b[a]) * E[k])
    W <- (if (c_ <= n) b[c_] else T_END) - b[a]
    nxt <- Mp / W
    w[i] <- from_prev + Ep - nxt
    from_prev <- nxt
  }
  w
}
J_of <- function(nd, keep) sum(weights_of(nd, keep) * fecundity_of(nd)[sort(unique(keep))])

# Each node's share of J' on the full schedule.
shares_of <- function(nd) {
  n <- length(nd$birth)
  v <- nd$w[1:n] * fecundity_of(nd)
  v / sum(v)
}

# Members per accepted step: those born at or before the step's start.
rows_of <- function(step_times, births) sum(as.numeric(findInterval(head(step_times, -1), sort(births))))

# Rule (a): keep the members born up to where the cumulative share reaches
# 1 - delta.
rule_a <- function(nd, delta) {
  cs <- cumsum(shares_of(nd))
  j <- which(cs >= 1 - delta)[1]
  if (is.na(j)) j <- length(cs)
  seq_len(j)
}

# Rule (b): spacing Delta0 * (c * s_max / s_j)^(1/3), never under the run's
# own; a panel is taken only if it fits every node it spans, and the last
# runs to the run's end.
rule_b <- function(nd, c) {
  s <- shares_of(nd); b <- nd$birth; n <- length(b)
  d0 <- b[2] - b[1]
  D <- ifelse(s > 0, d0 * pmax(1, (c * max(s) / s)^(1 / 3)), Inf)
  keep <- 1; i <- 1
  repeat {
    if (T_END - b[i] <= min(D[i:n])) break
    m <- i + 1
    while (m < n && b[m + 1] - b[i] <= min(D[i:(m + 1)])) m <- m + 1
    keep <- c(keep, m); i <- m
    if (i == n) break
  }
  keep
}
