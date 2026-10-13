# a04_proxy whose check leaves no wide interval unrefined: a gap between edges that the
# ratio R gives no new node has each of its intervals wider than half the target bisected,
# as c05_graded's check would. Every interval that can carry error then shrinks by
# 1/4 to 1/R^2, so the estimate barely depends on where the error sits.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a04_proxy.R", environment())
WIDE <- ev("WIDE", 0.5)
fill <- function(p, h, Sc, Sk) { ends <- sort(unique(c(0, p$edges, 39.6))); mc <- (head(Sc, -1) + Sc[-1]) / 2; mk <- (head(Sk, -1) + Sk[-1]) / 2
  oc <- p$shut(mc) < 0.5; gc <- cut(mc, ends); gk <- cut(mk[p$shut(mk) < 0.5], ends)
  same <- as.vector(table(gc[oc])[as.character(gc)] == table(gk)[as.character(gc)])
  add <- oc & same & diff(Sc) > WIDE * vapply(mc, h, 0) + 1e-9
  sort(unique(round(c(Sk, mc[add]), 10))) }
algorithm <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h); Sk <- fill(p, h, Sc, build_graded(p, function(b) h(b) / R))
  c <- ctx$run(Sc); k <- names(c$q); f <- ctx$run(Sk); d <- c$q[k] - f$q[k]; s <- proxy_err(p, Sk) / proxy_err(p, Sc)
  if (all(abs(d / (1 - s) / ctx$eps(k)) < TAU)) return(list(use = list(Sc), answer = c$q[k], estimate = d / (1 - s)))
  list(use = list(Sk), answer = f$q[k], estimate = d * s / (1 - s)) }
