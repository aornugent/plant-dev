# Shared pieces: the scorer's range, a gap-by-gap builder and bisection.
cap_of <- function(p, lo, hi) ifelse(hi <= p$b1 + 1e-9, p$b1 / 12, ifelse(lo < 20, 100 / 365, 280 / 365))
# Each open gap between edges gets an even number of equal intervals no wider than the
# narrowest target spacing inside it (an odd count only where halving would leave the
# range); returns S and the alternate nodes whose removal doubles every interval.
build2 <- function(p, hfun, H = 39.6) { ends <- sort(unique(c(0, p$edges, H))); G <- c(); dr <- numeric(0)
  for (i in seq_len(length(ends) - 1)) { a <- ends[i]; b <- ends[i + 1]; G <- c(G, a)
    if (p$shut((a + b) / 2) > 0.5) next
    h <- min(vapply(a + (b - a) * (1:20 - 0.5) / 20, hfun, 0)); n <- ceiling((b - a) / h - 1e-9); if (n <= 1) next
    if (2 * (b - a) / (n + n %% 2) <= cap_of(p, a, b) + 1e-12) n <- n + n %% 2
    x <- seq(a, b, length.out = n + 1); G <- c(G, x[2:n])
    if (n %% 2 == 0 && 2 * (b - a) / n <= cap_of(p, a, b) + 1e-12) dr <- c(dr, x[seq(2, n, by = 2)]) }
  G <- sort(unique(round(G, 10))); list(S = G, drop = which(G %in% round(dr, 10))) }
# Graded: each open gap gets ceiling(integral of 1/h) intervals placed by that measure,
# with h never above the scorer's range; equal spacing where h is flat.
build_graded <- function(p, hfun, H = 39.6) { ends <- sort(unique(c(0, p$edges, H))); G <- c()
  for (i in seq_len(length(ends) - 1)) { a <- ends[i]; b <- ends[i + 1]; G <- c(G, a)
    if (p$shut((a + b) / 2) > 0.5) next
    cp <- cap_of(p, a, b); u <- seq(a, b, length.out = 801); um <- (head(u, -1) + tail(u, -1)) / 2
    w <- 1 / pmin(vapply(um, hfun, 0), cp); cw <- c(0, cumsum(w * diff(u))); n <- ceiling(tail(cw, 1) - 1e-9)
    if (n <= 1) next
    x <- if (diff(range(w)) < 1e-12) seq(a, b, length.out = n + 1) else approx(cw / tail(cw, 1), u, seq(0, 1, length.out = n + 1), ties = "ordered")$y
    while (any(diff(x) > cp + 1e-10)) { n <- n + 1; x <- approx(cw / tail(cw, 1), u, seq(0, 1, length.out = n + 1), ties = "ordered")$y }
    G <- c(G, x[2:n]) }
  sort(unique(round(G, 10))) }
bisect <- function(p, S, keep = function(b) TRUE) { lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2
  sel <- p$shut(m) < 0.5 & vapply(m, keep, TRUE); sort(unique(round(c(S, m[sel]), 10))) }
# As build_graded, but the count per gap rounds to nearest (never past the range), so
# the spacing averages h instead of always erring finer.
build_round <- function(p, hfun, H = 39.6, up = 0.5) { ends <- sort(unique(c(0, p$edges, H))); G <- c()
  for (i in seq_len(length(ends) - 1)) { a <- ends[i]; b <- ends[i + 1]; G <- c(G, a)
    if (p$shut((a + b) / 2) > 0.5) next
    cp <- cap_of(p, a, b); u <- seq(a, b, length.out = 801); um <- (head(u, -1) + tail(u, -1)) / 2
    w <- 1 / pmin(vapply(um, hfun, 0), cp); cw <- c(0, cumsum(w * diff(u)))
    n <- max(1, floor(tail(cw, 1) + up), ceiling((b - a) / cp - 1e-9))
    if (n <= 1) next
    x <- if (diff(range(w)) < 1e-12) seq(a, b, length.out = n + 1) else approx(cw / tail(cw, 1), u, seq(0, 1, length.out = n + 1), ties = "ordered")$y
    while (any(diff(x) > cp + 1e-10)) { n <- n + 1; x <- approx(cw / tail(cw, 1), u, seq(0, 1, length.out = n + 1), ties = "ordered")$y }
    G <- c(G, x[2:n]) }
  sort(unique(round(G, 10))) }
