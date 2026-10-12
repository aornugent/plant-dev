# Round 1 candidates. Each certifies its answer with a coarser point and stops when every
# quantity's estimate is under eps/2.
source("/home/user/plant-dev/harness/schedule/baseline.R")
ok <- function(ctx, est) all(abs(est) < ctx$eps(names(est)) / 2)
pair <- function(ctx, fine, coarse) { a <- ctx$run(fine[1], fine[2]); b <- ctx$run(coarse[1], coarse[2])
  k <- intersect(names(a$q), names(b$q)); list(q = a$q[k], est = (a$q[k] - b$q[k]) / 3) }

# A2: a ladder from coarse to fine along the diagonal, stopping at the first certified level.
ladder <- function(levels = list(c(8, 140), c(16, 70), c(32, 35), c(64, 17.5))) function(ctx) {
  for (i in 2:length(levels)) { p <- pair(ctx, levels[[i]], levels[[i - 1]])
    if (ok(ctx, p$est) || i == length(levels)) return(list(use = list(levels[[i]]), answer = p$q, estimate = p$est)) } }

# A3: per-region Richardson. Run (f, l), (2f, l) and (f, l/2); each region's move is its
# error times 3/4 at the coarser spacing; choose each region's level so its predicted
# error is under its share of eps/2, then run that point once.
regional <- function(f = 16, l = 70, share = 0.5) function(ctx) {
  a <- ctx$run(f, l); bf <- ctx$run(2 * f, l); bl <- ctx$run(f, l / 2)
  k <- Reduce(intersect, list(names(a$q), names(bf$q), names(bl$q))); e <- ctx$eps(k) / 2
  ef <- abs(bf$q[k] - a$q[k]) * 4 / 3; el <- abs(bl$q[k] - a$q[k]) * 4 / 3   # errors at (f, l), per region
  lev <- function(err, budget, base, up) { m <- 0; while (any(err / 4^m > budget) && m < 3) m <- m + 1; if (up) base * 2^m else base / 2^m }
  F <- min(lev(ef, share * e, f, TRUE), 64); L <- max(lev(el, (1 - share) * e, l, FALSE), 17.5)
  fin <- ctx$run(F, L); est <- ef / 4^log2(F / f) + el / 4^log2(l / L)
  list(use = list(c(F, L)), answer = fin$q[k], estimate = est) }
