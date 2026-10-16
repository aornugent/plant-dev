# weights_check.R: the pair rule's node weights, offline, exactly as pairs.patch forms them.
# Hat weights from each interval's exact establishment E_i and first moment M_i; pairs of
# intervals from node 0 corrected by E_pair/H times (composite Simpson - hats) for a
# uniform density. Checks: uniform E gives composite Simpson for unequal widths; exact on
# quadratics (any widths) and cubics (equal widths); orders on a smooth toy integrand with
# uniform and non-uniform establishment; the moment-matched alternative beside it.
OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
moments <- function(b, e) { n <- length(b) - 1
  E <- M <- M2 <- numeric(n)
  for (i in seq_len(n)) { h <- b[i + 1] - b[i]
    E[i] <- integrate(function(s) e(b[i] + s), 0, h, rel.tol = 1e-13)$value
    M[i] <- integrate(function(s) s * e(b[i] + s), 0, h, rel.tol = 1e-13)$value
    M2[i] <- integrate(function(s) s^2 * e(b[i] + s), 0, h, rel.tol = 1e-13)$value }
  list(E = E, M = M, M2 = M2) }
hats <- function(b, m) { n <- length(b); w <- numeric(n); h <- diff(b)
  for (i in seq_len(n - 1)) { nx <- m$M[i] / h[i]; w[i] <- w[i] + m$E[i] - nx; w[i + 1] <- w[i + 1] + nx }
  w }
# The patch's rule. `sel(b0, b2)` selects pairs; pairs run j = 1, 3, 5, ... (node 0 first).
pairs <- function(b, m, sel = function(b0, b2) TRUE) { w <- hats(b, m); n <- length(b)
  j <- 1
  while (j + 2 <= n) { b0 <- b[j]; b1 <- b[j + 1]; b2 <- b[j + 2]
    if (sel(b0, b2)) { h1 <- b1 - b0; h2 <- b2 - b1; H <- h1 + h2; E <- m$E[j] + m$E[j + 1]
      c0 <- (2 - h2 / h1) / 6 - h1 / (2 * H); c1 <- H^2 / (6 * h1 * h2) - 0.5; c2 <- (2 - h1 / h2) / 6 - h2 / (2 * H)
      w[j:(j + 2)] <- w[j:(j + 2)] + E * c(c0, c1, c2) }
    j <- j + 2 }
  w }
# The alternative: the exact integral of the quadratic interpolant against E, with E's
# second moment per interval taken from a linear density matched to E_i and M_i
# (h M - h^2 E / 6, clamped to [M^2/E, h M]) -- the patch's PLANT_SIMPSON_FORM=moment;
# a trailing interval keeps plant's hat weights.
pairs_moment <- function(b, m) { n <- length(b); w <- numeric(n); h <- diff(b); j <- 1
  while (j + 2 <= n) { x <- b[j:(j + 2)] - b[j]; hh <- h[j:(j + 1)]
    m2i <- sapply(1:2, function(k) { E <- m$E[j + k - 1]; M <- m$M[j + k - 1]; v <- hh[k] * M - hh[k]^2 * E / 6
      if (E > 0) v <- min(max(v, M^2 / E), hh[k] * M); v })
    m0 <- m$E[j] + m$E[j + 1]; m1 <- m$M[j] + m$M[j + 1] + x[2] * m$E[j + 1]
    m2 <- m2i[1] + m2i[2] + 2 * x[2] * m$M[j + 1] + x[2]^2 * m$E[j + 1]
    for (k in 1:3) { o <- setdiff(1:3, k); w[j + k - 1] <- w[j + k - 1] + (m2 - sum(x[o]) * m1 + prod(x[o]) * m0) / prod(x[k] - x[o]) }
    j <- j + 2 }
  if (j < n) { nx <- m$M[j] / h[j]; w[j] <- w[j] + m$E[j] - nx; w[j + 1] <- w[j + 1] + nx }
  w }
simpson_nonuniform <- function(b) { n <- length(b); w <- numeric(n); j <- 1
  while (j + 2 <= n) { h1 <- b[j + 1] - b[j]; h2 <- b[j + 2] - b[j + 1]; H <- h1 + h2
    w[j:(j + 2)] <- w[j:(j + 2)] + H / 6 * c(2 - h2 / h1, H^2 / (h1 * h2), 2 - h1 / h2); j <- j + 2 }
  if (j < n) w[j:(j + 1)] <- w[j:(j + 1)] + (b[j + 1] - b[j]) / 2
  w }
log <- file(file.path(OUT, "weights_check.log"), "w"); say <- function(...) { cat(..., "\n", sep = ""); cat(..., "\n", sep = "", file = log) }
set.seed(1)
b <- cumsum(c(0, runif(10, 0.05, 0.4)))  # ten unequal widths: five pairs
one <- function(x) 1 + 0 * x
m1 <- moments(b, one)
say(sprintf("A. uniform E, 10 unequal widths (ratio up to %.1f): max |pair rule - composite Simpson| = %.2e",
  max(diff(b)[-1] / head(diff(b), -1)), max(abs(pairs(b, m1) - simpson_nonuniform(b)))))
for (p in 0:4) { f <- function(x) x^p; ex <- (max(b)^(p + 1)) / (p + 1)
  say(sprintf("   f = x^%d: hats %+.2e, pair rule %+.2e, moment rule %+.2e (relative error)", p,
    sum(hats(b, m1) * f(b)) / ex - 1, sum(pairs(b, m1) * f(b)) / ex - 1, sum(pairs_moment(b, m1) * f(b)) / ex - 1)) }
be <- seq(0, 2, length.out = 11); me <- moments(be, one)
for (p in 3:5) { f <- function(x) x^p; ex <- (2^(p + 1)) / (p + 1)
  say(sprintf("B. equal widths, f = x^%d: pair rule relative error %+.2e", p, sum(pairs(be, me) * f(be)) / ex - 1)) }
# Non-uniform establishment: does the rule still reach fourth order?
say("C. orders on f = exp(-b/0.6) over [0, 3.5], E(b) as below; N intervals; uniform and graded (widths alternating 1:2) grids")
f <- function(x) exp(-x / 0.6)
for (en in list(list("uniform", one), list("linear 1+0.5b", function(x) 1 + 0.5 * x), list("exp(-b)", function(x) exp(-x)),
                list("gate (1-b/3.6)^2", function(x) pmax(1 - x / 3.6, 0)^2))) {
  ex <- integrate(function(x) en[[2]](x) * f(x), 0, 3.5, rel.tol = 1e-14)$value
  for (grid in c("uniform", "graded")) { er <- NULL
    for (N in c(6, 12, 24, 48)) { b <- if (grid == "uniform") seq(0, 3.5, length.out = N + 1) else { w <- rep(c(1, 2), N / 2); c(0, cumsum(w)) / sum(w) * 3.5 }
      m <- moments(b, en[[2]]); er <- rbind(er, c(N, sum(hats(b, m) * f(b)) / ex - 1, sum(pairs(b, m) * f(b)) / ex - 1, sum(pairs_moment(b, m) * f(b)) / ex - 1)) }
    ord <- function(k) log2(abs(er[-nrow(er), k] / er[-1, k]))
    say(sprintf("   E %-17s %-7s err at N=12: hats %+.2e pair %+.2e moment %+.2e | orders hats %s | pair %s | moment %s", en[[1]], grid,
      er[2, 2], er[2, 3], er[2, 4], paste(sprintf("%.2f", ord(2)), collapse = " "), paste(sprintf("%.2f", ord(3)), collapse = " "), paste(sprintf("%.2f", ord(4)), collapse = " "))) } }
# Negative weights: a node's pair rule weight under uniform E, as a function of width ratio.
say("D. uniform E: end-node weight of a pair (per unit density) H/6 (2 - h2/h1) is negative when h2 > 2 h1;")
for (r in c(1, 1.5, 2, 3, 5)) say(sprintf("   h2/h1 = %.1f: pair weights / H = %s", r, paste(sprintf("%+.3f", simpson_nonuniform(c(0, 1, 1 + r)) / (1 + r)), collapse = " ")))
# Gaps: spells of 0.30 y with establishment 1, gaps of 0.12 y with none, over [0, 3];
# nodes as the inset layout puts them: 0.033 y (12 d) inside each spell's ends plus one
# node mid-spell, no node in a gap (L-like); and every interval halved (H2-like: a node
# mid-gap). Fate f smooth, or f collapsing to 0.1 f for cohorts born in a gap.
say("E. gaps (inset layout): relative error in the integral of E f")
sp <- 0.30; gp <- 0.12; per <- sp + gp; starts <- seq(0, 3 - per, by = per)
Eg <- function(x) as.numeric((x %% per) < sp)
inset <- 12 / 365
Lg <- sort(unique(c(0, unlist(lapply(starts, function(a) c(a + inset, a + sp / 2, a + sp - inset))))))
Lg <- Lg[Lg <= max(starts) + sp - inset]
for (fg in list(list("smooth fate", function(x) exp(-x / 0.6)), list("fate x0.1 in gaps", function(x) exp(-x / 0.6) * ifelse((x %% per) < sp, 1, 0.1)))) {
  for (lay in c("L-like", "H2-like")) { b <- if (lay == "L-like") Lg else sort(c(Lg, (head(Lg, -1) + Lg[-1]) / 2))
    ex <- sum(sapply(seq_len(length(b) - 1), function(i) integrate(function(x) Eg(x) * fg[[2]](x), b[i], b[i + 1], subdivisions = 2000, rel.tol = 1e-12)$value))
    m <- moments(b, Eg); wh <- hats(b, m); wu <- pairs(b, m); wm <- pairs_moment(b, m)
    say(sprintf("   %-18s %-8s nodes %3d | hats %+.2e | uniform form %+.2e | moment form %+.2e | negative weights: hats %d, uniform %d, moment %d",
      fg[[1]], lay, length(b), sum(wh * fg[[2]](b)) / ex - 1, sum(wu * fg[[2]](b)) / ex - 1, sum(wm * fg[[2]](b)) / ex - 1, sum(wh < -1e-12), sum(wu < -1e-12), sum(wm < -1e-12))) } }
close(log)
