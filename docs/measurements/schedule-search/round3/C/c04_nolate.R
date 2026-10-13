# a05_fill whose check leaves births after LATE as the committed schedule has them: the
# check refines (ratio and fill) only where d is not about zero.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/base.R", environment())
LATE <- ev("LATE", 25)
fill_before <- function(p, h, Sc, Sk) { F <- fill(p, h, Sc, Sk); add <- setdiff(round(F, 10), round(Sk, 10)); sort(unique(round(c(Sk, add[add < LATE]), 10))) }
algorithm <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h)
  Sk <- fill_before(p, h, Sc, build_graded(p, function(b) if (b < LATE) h(b) / R else h(b)))
  c <- ctx$run(Sc); k <- names(c$q); f <- ctx$run(Sk); d <- c$q[k] - f$q[k]; s <- proxy_err(p, Sk) / proxy_err(p, Sc)
  if (all(abs(d / (1 - s) / ctx$eps(k)) < TAU)) return(list(use = list(Sc), answer = c$q[k], estimate = d / (1 - s)))
  list(use = list(Sk), answer = f$q[k], estimate = d * s / (1 - s)) }
