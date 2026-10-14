# Uses sized to the measured error: after the find (a05_fill's pair), a coarse commit
# whose largest estimate m is under TAU_USE has its uses run a schedule whose spacing is
# h * min(GMAX, sqrt(TAU_USE / m)), estimate scaled by the proxy. The find's pair is unchanged.
sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a05_fill.R", environment())
base_algorithm <- algorithm
TAU_USE <- ev("TAU_USE", 0.7); GMAX <- ev("GMAX", 2)
USE_COST <- new.env(); USE_COST$v <- c()
algorithm <- function(ctx) { out <- base_algorithm(ctx); p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h)
  k <- names(out$estimate); m <- max(abs(out$estimate / ctx$eps(k)))
  coarse <- length(out$use[[1]]) == length(Sc) && all(abs(out$use[[1]] - Sc) < 1e-9)
  g <- if (coarse) min(GMAX, sqrt(TAU_USE / m)) else 1
  if (g <= 1.02) { USE_COST$v <- c(USE_COST$v, 0); return(out) }
  S2 <- build_graded(p, function(b) h(b) * g); r <- ctx$run(S2)
  USE_COST$v <- c(USE_COST$v, run_cost(r$rows, TRUE))     # charged to find by the scorer; it is a use
  list(use = list(S2), answer = r$q[k], estimate = out$estimate * proxy_err(p, S2) / proxy_err(p, Sc)) }
