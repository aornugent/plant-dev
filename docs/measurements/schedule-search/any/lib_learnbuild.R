# Shared pieces: coarse learning grid, density from its map, equidistributed build.
H <- 39.6
caps <- function(p, lo, hi) ifelse(hi <= p$b1 + 1e-9, p$b1 / 12, ifelse(lo < 20, 100 / 365, 280 / 365))
gaps <- function(p) { e <- sort(unique(c(0, p$edges, H))); data.frame(a = e[-length(e)], b = e[-1]) }
# Coarse grid: each open gap cut into an even number of equal intervals no wider than
# fac x the range cap; every other node is dropped for the map.
coarse <- function(p, fac = 1) { g <- gaps(p); S <- c(); drop <- c()
  for (i in seq_len(nrow(g))) { a <- g$a[i]; b <- g$b[i]; open <- p$shut((a + b) / 2) < 0.5
    cap <- fac * caps(p, a, b) * (1 - 1e-6); r <- (b - a) / cap; n <- if (!open) 1 else if (r <= 1 && (b - a) < 0.02) 1 else max(2, 2 * ceiling(r / 2))
    x <- seq(a, b, length.out = n + 1)[-(n + 1)]; S <- c(S, x); if (n > 1) drop <- c(drop, x[seq(2, n, by = 2)]) }
  S <- sort(unique(round(S, 10))); j <- which(S %in% round(drop, 10)); list(S = S, drop = j[j > 1 & j < length(S)]) }
# d per panel from the map: m = d((h1+h2)^3 - h1^3 - h2^3).
panels <- function(S, drop, map) { j <- drop; h1 <- S[j] - S[j - 1]; h2 <- S[j + 1] - S[j]
  data.frame(lo = S[j - 1], hi = S[j + 1], d = map$move / ((h1 + h2)^3 - h1^3 - h2^3)) }
dfun <- function(P) { P <- P[order(P$lo), ]; mids <- (P$lo + P$hi) / 2
  function(b) { i <- findInterval(b, P$lo); i[i < 1] <- 1; ok <- b < P$hi[i]
    k <- ifelse(ok, i, vapply(b, function(x) which.min(abs(mids - x)), 1L)); P$d[k] } }
# Width of the schedule interval holding b.
spacing <- function(S) { w <- diff(c(S, H)); function(b) w[pmax(1, findInterval(b, S))] }
band <- function(b, b1) cut(b, c(-1, b1, 10, 100), labels = FALSE, right = FALSE)
# Predicted per-band sum of |d| h^3 for schedule S.
Xpred <- function(S, d, p) { lo <- S[-length(S)]; hi <- S[-1]; m <- (lo + hi) / 2
  e <- abs(d(m)) * (hi - lo)^3; e[p$shut(m) > 0.5] <- 0; tapply(factor(band(m, p$b1), 1:3), X = e, FUN = sum, default = 0) }
# Equidistributed schedule: h(b) = lam[band] (w(b)/|d(b)|)^(1/3), capped by the range and by
# hmax(b); w(b) = A + (H - b) is the cost per node. Nodes sit at equal steps of int 1/h.
prep <- function(p, d, hmax, A = 0.8, floor_d = 1e-6, K = 121) { g <- gaps(p)
  lapply(seq_len(nrow(g)), function(i) { a <- g$a[i]; b <- g$b[i]
    if (p$shut((a + b) / 2) > 0.5 || b - a < 1e-9) return(list(a = a, fixed = TRUE))
    x <- seq(a, b, length.out = K); m <- (x[-1] + x[-K]) / 2
    list(a = a, b = b, x = x, cap = caps(p, a, b), cp = pmin(caps(p, a, b), hmax(m)), bd = band(m, p$b1),
         base = ((A + H - m) / pmax(abs(d(m)), floor_d))^(1 / 3), fixed = FALSE) }) }
build_gap <- function(G, lam) { if (G$fixed) return(G$a)
  h <- pmin(G$cp, lam[G$bd] * G$base); F <- c(0, cumsum(diff(G$x) / h)); n <- max(1, ceiling(tail(F, 1) - 1e-9))
  repeat { z <- approx(F, G$x, seq(0, tail(F, 1), length.out = n + 1), ties = "ordered")$y
    if (all(diff(z) <= G$cap * (1 - 1e-6))) break; n <- n + 1 }
  z[-(n + 1)] }
build_prep <- function(PG, lam) sort(unique(round(unlist(lapply(PG, build_gap, lam)), 10)))
build <- function(p, d, lam, hmax, A = 0.8) build_prep(prep(p, d, hmax, A), lam)
# Solve lam per band so the predicted band sums are rho[band] times the reference's.
build_rho <- function(p, d, Xref, rho, hmax, A = 0.8, PG = prep(p, d, hmax, A)) { lam <- c(1, 1, 1); rho <- rep(rho, length.out = 3)
  for (k in 1:3) { if (Xref[k] <= 0) next
    sub <- PG[vapply(PG, function(G) !G$fixed && any(G$bd == k), TRUE)]
    f <- function(l) { L <- lam; L[k] <- exp(l); Xpred(c(build_prep(sub, L), sub[[length(sub)]]$b), d, p)[k] / Xref[k] - rho[k] }
    lo <- -12; hi <- 4
    if (f(hi) < 0) { lam[k] <- exp(hi); next }
    for (it in 1:22) { mid <- (lo + hi) / 2; if (f(mid) > 0) hi <- mid else lo <- mid }
    lam[k] <- exp(lo) }
  S <- build_prep(PG, lam); list(S = S, lam = lam, ratio = Xpred(S, d, p) / Xref) }
# |d| interpolated linearly between the map's sample points (the dropped nodes), optionally
# floored at q times the median of its neighbours within k samples.
dlin <- function(S, drop, map, q = 0, k = 2) { P <- panels(S, drop, map); x <- S[drop]; y <- abs(P$d)
  if (q > 0) { n <- length(y); y <- vapply(seq_len(n), function(i) max(y[i], q * median(y[max(1, i - k):min(n, i + k)])), 0) }
  function(b) approx(x, y, b, rule = 2)$y }
# Every other interior node of S within each edge gap: a map on S.
alt_drop <- function(S, p) { e <- c(0, p$edges); g <- findInterval(S, e + 1e-9) ; j <- integer(0)
  for (k in unique(g)) { i <- which(g == k); if (length(i) >= 3) j <- c(j, i[seq(2, length(i) - 1, by = 2)]) }
  j[j > 1 & j < length(S) & p$shut(S[j]) < 0.5] }
# |d| from several maps pooled: linear between all sample points.
dpool <- function(L) { x <- unlist(lapply(L, function(z) z$S[z$drop])); y <- unlist(lapply(L, function(z) abs(panels(z$S, z$drop, z$map)$d)))
  o <- order(x); x <- x[o]; y <- y[o]; k <- !duplicated(x); x <- x[k]; y <- y[k]; function(b) approx(x, y, b, rule = 2)$y }
