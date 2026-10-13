# a04_proxy with a shrink that does not depend on where the error sits: the largest of
# the proxy's shrinks over the bands before b1, b1-10, 10-20 and after 20.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a04_proxy.R", environment())
band_err <- function(p, S) { n <- p$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2; w <- exp(PW * lf(m)); w[p$shut(m) > 0.5] <- 0
  tapply(w * (hi - lo)^3, cut(m, c(0, p$b1, 10, 20, 40)), sum) }
shrink <- function(p, Sc, Sf) { a <- band_err(p, Sc); b <- band_err(p, Sf); ok <- a > 1e-3 * sum(a); max((b / a)[ok]) }
algorithm <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h); Sk <- build_graded(p, function(b) h(b) / R)
  c <- ctx$run(Sc); k <- names(c$q); f <- ctx$run(Sk); d <- c$q[k] - f$q[k]; s <- shrink(p, Sc, Sk)
  if (all(abs(d / (1 - s) / ctx$eps(k)) < TAU)) return(list(use = list(Sc), answer = c$q[k], estimate = d / (1 - s)))
  list(use = list(Sk), answer = f$q[k], estimate = d * s / (1 - s)) }
