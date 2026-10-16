# split.R: a nested pair's move split exactly into establishment, field and interpolation
# parts (the founders' q2_shape split, generalised to any nesting): the coarse hats written in
# the fine hat basis, w~_i = sum_f w_f * phi_i(x_f). interp = ln(sum w~ nrr_f) - ln(sum w_f nrr_f):
# the coarse quadrature of the fine run's fates, in the fine run's field.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
hatw <- function(bc, bf, wf) { # coarse weights from fine weights, coarse nodes bc subset of bf
  W <- numeric(length(bc)); j <- findInterval(bf, bc, rightmost.closed = TRUE); j[j < 1] <- 1; j[j >= length(bc)] <- length(bc) - 1
  t <- (bf - bc[j]) / (bc[j + 1] - bc[j]); t <- pmin(pmax(t, 0), 1)
  for (f in seq_along(bf)) { W[j[f]] <- W[j[f]] + wf[f] * (1 - t[f]); W[j[f] + 1] <- W[j[f] + 1] + wf[f] * t[f] }; W }
nodes <- function(x) { n <- x$stand$nodes; m <- length(n$birth); list(b = n$birth, w = n$establishment[1:m], g = n$nrr) }
interp_part <- function(fine, bc) { f <- nodes(fine); stopifnot(all(round(bc, 8) %in% round(f$b, 8)))
  kc <- match(round(bc, 8), round(f$b, 8)); W <- hatw(f$b[kc], f$b, f$w); log(sum(W * f$g[kc])) - log(sum(f$w * f$g)) }
split <- function(coarse, fine) { c0 <- nodes(coarse); f <- nodes(fine); kc <- match(round(c0$b, 8), round(f$b, 8)); stopifnot(!anyNA(kc))
  W <- hatw(c0$b, f$b, f$w); A <- sum(f$w * f$g)
  c(total = log(coarse$stand$J / fine$stand$J), est = sum((c0$w - W) * c0$g) / A, field = sum(W * (c0$g - f$g[kc])) / A, interp = sum(W * f$g[kc]) / A - 1) }
