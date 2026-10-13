# Nested checks on a05's committed schedule; the check contains it, so the pair shares
# jitter. MODE "all": bisect every open interval wider than WIDE of its target (s = 1/4).
# MODE "top": bisect the intervals with the largest proxy error until they hold PHI of it;
# s = the proxy's shrink. Both estimate move/(1 - s).
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/base.R", environment())
MODE <- Sys.getenv("MODE", "all"); PHI <- ev("PHI", 0.8); LATE <- ev("LATE", 40)
proxy_int <- function(p, S) { n <- p$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2; w <- exp(PW * lf(m)); w[p$shut(m) > 0.5] <- 0; w * (hi - lo)^3 }
nested_check <- function(p, h, Sc) { lo <- head(Sc, -1); hi <- Sc[-1]; m <- (lo + hi) / 2; open <- p$shut(m) < 0.5
  sel <- if (MODE == "all") open & (hi - lo) > WIDE * vapply(m, h, 0) + 1e-9 else {
    e <- proxy_int(p, Sc); o <- order(-e); k <- which(cumsum(e[o]) >= PHI * sum(e))[1]; seq_along(m) %in% o[seq_len(k)] }
  sort(unique(round(c(Sc, m[sel & open & m < LATE]), 10))) }
algorithm <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h); Sk <- nested_check(p, h, Sc)
  c <- ctx$run(Sc); k <- names(c$q); f <- ctx$run(Sk); d <- c$q[k] - f$q[k]; s <- proxy_err(p, Sk) / proxy_err(p, Sc)
  if (all(abs(d / (1 - s) / ctx$eps(k)) < TAU)) return(list(use = list(Sc), answer = c$q[k], estimate = d / (1 - s)))
  list(use = list(Sk), answer = f$q[k], estimate = d * s / (1 - s)) }
