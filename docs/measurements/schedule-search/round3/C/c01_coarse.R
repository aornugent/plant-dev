# Check coarser than the committed run: the widest legal schedule. Its error is s times
# the committed one's, s > 1 from the pilot proxy, so the committed error is move/(s - 1).
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/base.R", environment())
algorithm <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h); Sw <- widest(p)
  c <- ctx$run(Sc); k <- names(c$q); w <- ctx$run(Sw); d <- w$q[k] - c$q[k]; s <- proxy_err(p, Sw) / proxy_err(p, Sc)
  list(use = list(Sc), answer = c$q[k], estimate = d / (s - 1)) }
