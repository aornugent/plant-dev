# A continuous surrogate over the lattice runs: any founders' count f and late spacing l
# (days). Each region's move is interpolated piecewise-linearly in h^2 between stored
# levels (Richardson between neighbours), extrapolated to h -> 0 on the square law, and
# the regions add about the centre (16, 70). Cost: rows linear in node count, per case.
source("/home/user/plant-dev/harness/schedule/evaluate.R")

fit_case <- function(case) {
  lib <- cached(paste0("lib:", case), function() load_library(case))
  get <- function(f, l) lib[[sprintf("%s/%s", format(f), format(l))]]
  fs <- F_LEVELS[vapply(F_LEVELS, function(f) !is.null(get(f, 70)), TRUE)]
  ls <- L_LEVELS[vapply(L_LEVELS, function(l) !is.null(get(16, l)), TRUE)]
  k <- Reduce(intersect, c(lapply(fs, function(f) names(get(f, 70)$q)), lapply(ls, function(l) names(get(16, l)$q))))
  c0 <- get(16, 70)$q[k]
  # moves from the centre along each axis, at x = h^2 (founders: h = 1/f; late: h = l)
  xF <- (1 / fs)^2; DF <- t(sapply(fs, function(f) get(f, 70)$q[k] - c0))
  xL <- ls^2; DL <- t(sapply(ls, function(l) get(16, l)$q[k] - c0))
  limit <- function(x, D) { o <- order(x); a <- o[1]; b <- o[2]; D[a, ] + (D[a, ] - D[b, ]) * x[a] / (x[b] - x[a]) }  # h -> 0
  F0 <- rbind(DF, limit(xF, DF)); xF0 <- c(xF, 0); L0 <- rbind(DL, limit(xL, DL)); xL0 <- c(xL, 0)
  interp <- function(x, xs, D) { o <- order(xs); xs <- xs[o]; D <- D[o, , drop = FALSE]
    if (x < 0 || x > max(xs)) return(NULL)
    i <- max(which(xs <= x)); if (i == length(xs)) return(D[i, ]); w <- (x - xs[i]) / (xs[i + 1] - xs[i]); D[i, ] + w * (D[i + 1, ] - D[i, ]) }
  # rows ~ a + b * nodes over every stored point
  pts <- do.call(rbind, lapply(names(lib), function(n) { p <- lib[[n]]; data.frame(nodes = length(lattice_schedule(case, p$f, p$l)), rows = p$rows) }))
  m <- lm(rows ~ nodes, pts)
  list(q = function(f, l) { a <- interp(1 / f^2, xF0, F0); b <- interp(l^2, xL0, L0); if (is.null(a) || is.null(b)) return(NULL); c0 + a + b },
       rows = function(f, l) unname(predict(m, data.frame(nodes = length(lattice_schedule(case, f, l))))), r2 = summary(m)$r.squared, keys = k)
}

# The evaluator's lookup, replaced: stored points exactly, anything else from the fit.
lookup <- function(lib, f, l, f0 = 16, l0 = 70) {
  p <- lib[[sprintf("%s/%s", format(f), format(l))]]
  if (!is.null(p)) return(list(q = p$q, rows = p$rows, exact = TRUE))
  fit <- cached(paste0("fit:", attr(lib, "case")), function() fit_case(attr(lib, "case")))
  q <- fit$q(f, l); if (is.null(q)) return(NULL)
  list(q = q, rows = fit$rows(f, l), exact = FALSE)
}
load_library_plain <- load_library
load_library <- function(case) { lib <- load_library_plain(case); attr(lib, "case") <- case; lib }
