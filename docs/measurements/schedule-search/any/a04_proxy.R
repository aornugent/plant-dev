# Family (f): the check refines the committed schedule by one ratio R < 2 everywhere
# (not nested), so it costs less than a bisection; the committed error is the move
# over (1 - s), s = 1/R^2 the shrink of every interval's h^2.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/any/structure/common.R")
ev <- function(n, d) as.numeric(Sys.getenv(n, d))
R <- ev("R", 1.41); LAYER <- ev("LAYER", 24); FALL <- ev("FALL", 10); K <- ev("K", 0.2); BG <- ev("BG", 85); TAU <- ev("TAU", 1)
layer_end <- function(p) { n <- p$nodes[p$nodes$birth < p$b1, ]; y <- log(pmax(n$nrr, 1e-30)); t <- log(n$nrr[1] / FALL)
  i <- which(y < t)[1]; if (is.na(i)) return(p$b1); if (i == 1) return(0)
  n$birth[i - 1] + (y[i - 1] - t) / (y[i - 1] - y[i]) * (n$birth[i] - n$birth[i - 1]) }
capf <- function(p, b) if (b < p$b1) p$b1 / 12 else if (b < 20) 100 / 365 else 280 / 365
hfun_of <- function(p) { l1 <- layer_end(p); n <- p$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  ref <- median(log(pmax(n$nrr[n$birth > p$b1 & n$birth < 20], 1e-300)))
  function(b) min(capf(p, b), if (b < p$b1) { if (b < l1) p$b1 / LAYER else p$b1 / 12 } else BG / 365 * max(1, exp(K * (ref - lf(b))))) }
PW <- ev("PW", 0.6)
# The shrink s from the two schedules themselves: each interval errs as w h^3, w the pilot's
# offspring to the power PW, so gaps too short to refine count in both runs.
proxy_err <- function(p, S) { n <- p$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2; w <- exp(PW * lf(m)); w[p$shut(m) > 0.5] <- 0; sum(w * (hi - lo)^3) }
algorithm <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h); Sk <- build_graded(p, function(b) h(b) / R)
  c <- ctx$run(Sc); k <- names(c$q); f <- ctx$run(Sk); d <- c$q[k] - f$q[k]; s <- proxy_err(p, Sk) / proxy_err(p, Sc)
  if (all(abs(d / (1 - s) / ctx$eps(k)) < TAU)) return(list(use = list(Sc), answer = c$q[k], estimate = d / (1 - s)))
  list(use = list(Sk), answer = f$q[k], estimate = d * s / (1 - s)) }
