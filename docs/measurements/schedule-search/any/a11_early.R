# a09 whose check is refined only before LATE: after it the check keeps the committed
# run's nodes, so that region's error is in both runs and the shrink is read before LATE.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a09_late.R", environment())
LATE <- ev("LATE", 25)
proxy_before <- function(p, S) { n <- p$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2; w <- exp(PW * lf(m)); w[p$shut(m) > 0.5 | m >= LATE] <- 0; sum(w * (hi - lo)^3) }
shrink <- function(p, Sc, Sk) proxy_before(p, Sk) / proxy_before(p, Sc)
a09_algorithm <- algorithm
algorithm <- function(ctx) { run0 <- ctx$run; calls <- 0; Sc <- NULL
  ctx$run <- function(S, ...) { calls <<- calls + 1
    if (calls == 1) Sc <<- S else S <- sort(unique(round(c(S[S < LATE], Sc[Sc >= LATE]), 10)))
    run0(S, ...) }
  proxy_err <<- function(p, S) proxy_before(p, S)
  a09_algorithm(ctx) }
