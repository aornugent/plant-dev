# refs.R CASE: a reference ladder built here (u215, u429, u857, held-out recipe): own moves,
# the order from the two moves, and the shift against the reference used before.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R")
cs <- commandArgs(TRUE)[1]
g <- function(n) { x <- RF_RUN(sprintf("ref_%s_u%d", cs, n)); if (is.null(x)) x <- HO_RUN(sprintf("ref_%s_u%d", cs, n)); if (!is.null(x)) qv(x) }
a <- g(215); b <- g(429); c8 <- g(857)
m1 <- (b - a) / EPS; m2 <- (c8 - b) / EPS; k <- abs(m1) > 0.3
old <- if (cs %in% BANK) LAD$L[[cs]]$ref[Q] else extrap(a, b)
new <- extrap(b, c8); two <- extrap(a, b)
cat(sprintf("%s: own u215-u429 max %.3f (%s) | own u429-u857 max %.3f (%s) rms %.3f | order median %.2f over %d | new vs u215-u429 ref max %.3f | new vs old ref max %.3f (%s) rms %.3f\n",
  cs, max(abs(m1 / 3)), Q[which.max(abs(m1))], max(abs(m2 / 3)), Q[which.max(abs(m2))], sqrt(mean((m2 / 3)^2)), median(log2(abs(m1[k] / m2[k]))), sum(k),
  max(abs(new - two) / EPS), max(abs(new - old) / EPS), Q[which.max(abs(new - old) / EPS)], sqrt(mean(((new - old) / EPS)^2))))
e6 <- e6_runs(cs); for (nm in c("x0", "x1")) { e <- (qv(e6[[nm]]) - new) / EPS; eo <- (qv(e6[[nm]]) - old) / EPS
  cat(sprintf("  E6 %s: W new %.3f (%s), W old %.3f\n", nm, max(abs(e)), Q[which.max(abs(e))], max(abs(eo)))) }
