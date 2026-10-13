# Nested fractional check: bisect a fraction PHI of the answer's open intervals, spread
# evenly along the schedule; the check contains the answer, so the pair shares jitter.
# move = (3/4) * error in bisected intervals; s from the pilot proxy as in a04.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/any/lateral/a04_proxy.R", local = TRUE)
BG <- ev("BG", 90); PHI <- ev("PHI", 0.5); TAU <- ev("TAU", 1)
pick <- function(p, S) { lo <- head(S, -1); hi <- S[-1]; m <- (lo + hi) / 2; open <- which(p$shut(m) < 0.5)
  i <- seq_along(open); sel <- open[floor(i * PHI + 1e-9) != floor((i - 1) * PHI + 1e-9)]; m[sel] }
pair <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h); Sk <- sort(unique(round(c(Sc, pick(p, Sc)), 10)))
  list(A = Sc, C = Sk, s = proxy_err(p, Sk) / proxy_err(p, Sc)) }
algorithm <- function(ctx) { P <- pair(ctx); c <- ctx$run(P$A); k <- names(c$q); f <- ctx$run(P$C); d <- c$q[k] - f$q[k]; s <- P$s
  if (all(abs(d / (1 - s) / ctx$eps(k)) < TAU)) return(list(use = list(P$A), answer = c$q[k], estimate = d / (1 - s)))
  list(use = list(P$C), answer = f$q[k], estimate = d * s / (1 - s)) }
