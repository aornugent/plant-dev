# Structure-first committed schedule, read from the pilot alone:
#   first-mover layer (until the pilot's offspring per founder has fallen FALL-fold) at
#   b1/24, the window's quiet middle at b1/12; after b1 a background of BG days that
#   widens as h ~ (pilot offspring)^-K below its median between b1 and 20 (d tracks
#   offspring as about its 0.6 power, and h goes as d^-1/3), up to the range.
# The check halves every interval wider than half its target, so 4/3 of the move reads
# the committed error in every region at once. Commit the coarse run when that estimate
# is within eps everywhere, else the fine run with a third of the move.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/any/structure/common.R")
ev <- function(n, d) as.numeric(Sys.getenv(n, d))
LAYER <- ev("LAYER", 24); QUIET <- ev("QUIET", 12); FALL <- ev("FALL", 10); BG <- ev("BG", 85); K <- ev("K", 0.2); TAU <- ev("TAU", 1); WIDE <- 0.5
layer_end <- function(p) { n <- p$nodes[p$nodes$birth < p$b1, ]; y <- log(pmax(n$nrr, 1e-30)); t <- log(n$nrr[1] / FALL)
  i <- which(y < t)[1]; if (is.na(i)) return(p$b1); if (i == 1) return(0)
  n$birth[i - 1] + (y[i - 1] - t) / (y[i - 1] - y[i]) * (n$birth[i] - n$birth[i - 1]) }
hfun_of <- function(p) { l1 <- layer_end(p); n <- p$nodes; lf <- approxfun(n$birth, log(pmax(n$nrr, 1e-300)), rule = 2)
  ref <- median(log(pmax(n$nrr[n$birth > p$b1 & n$birth < 20], 1e-300)))
  function(b) if (b < p$b1) { if (b < l1) p$b1 / LAYER else p$b1 / QUIET } else min(if (b < 20) 100 / 365 else 280 / 365, BG / 365 * max(1, exp(K * (ref - lf(b))))) }
algorithm <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h)
  mid <- (head(Sc, -1) + Sc[-1]) / 2; wide <- diff(Sc) > WIDE * vapply(mid, h, 0) + 1e-9
  Sf <- sort(unique(round(c(Sc, mid[wide & p$shut(mid) < 0.5]), 10)))
  c <- ctx$run(Sc); f <- ctx$run(Sf); k <- names(c$q); d <- c$q[k] - f$q[k]
  if (all(abs(4 / 3 * d / ctx$eps(k)) < TAU)) return(list(use = list(Sc), answer = c$q[k], estimate = 4 / 3 * d))
  list(use = list(Sf), answer = f$q[k], estimate = d / 3) }
