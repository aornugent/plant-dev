# Coarse check with room: the committed schedule is built RC times finer than the check
# wherever the check is legal, so the check coarsens every region by about RC and the
# committed error is move/(s - 1). Gaps the ratio leaves at one count are bisected in the
# committed schedule when wider than WIDE of its target, so the check widens them too.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/base.R", environment())
RC <- ev("RC", 1.25); FILLC <- ev("FILLC", 1)
algorithm <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); hY <- function(b) min(capf(p, b), h(b) * RC); hX <- function(b) hY(b) / RC
  Sw <- build_graded(p, hY); Sc <- build_graded(p, hX); if (FILLC) Sc <- fill(p, hX, Sw, Sc)
  c <- ctx$run(Sc); k <- names(c$q); w <- ctx$run(Sw); d <- w$q[k] - c$q[k]; s <- proxy_err(p, Sw) / proxy_err(p, Sc)
  list(use = list(Sc), answer = c$q[k], estimate = d / (s - 1)) }
