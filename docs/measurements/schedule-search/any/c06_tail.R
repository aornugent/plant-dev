# Structure-first committed schedule from the pilot alone:
#   first-mover layer (births until the pilot's offspring per founder has fallen 10-fold)
#   at b1/24; the window's quiet middle at b1/12; the background to b = 20 at 85 d (the
#   range allows 100 d, so the background has no room to grade); 20-25 at 160 d (nodes cost about half, d about a fifth), after 25 at 280 d.
# The check halves every interval wider than half its target spacing, so each checked
# interval's error falls 4-fold and 4/3 of the move reads the committed error in every
# region at once. Commit the coarse run when that estimate is within eps everywhere;
# otherwise commit the fine run with a third of the move.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/any/structure/common.R")
LAYER <- 24; QUIET <- 12; FALL <- 10; BG <- 85; TAIL <- 160; TB <- 25; TAU <- 1; WIDE <- 0.5
layer_end <- function(p) { n <- p$nodes[p$nodes$birth < p$b1, ]; y <- log(pmax(n$nrr, 1e-30)); t <- log(n$nrr[1] / FALL)
  i <- which(y < t)[1]; if (is.na(i)) return(p$b1); if (i == 1) return(0)
  n$birth[i - 1] + (y[i - 1] - t) / (y[i - 1] - y[i]) * (n$birth[i] - n$birth[i - 1]) }
hfun_of <- function(p) { l1 <- layer_end(p)
  function(b) if (b < p$b1) { if (b < l1) p$b1 / LAYER else p$b1 / QUIET } else if (b < 20) BG / 365 else if (b < TB) TAIL / 365 else 280 / 365 }
algorithm <- function(ctx) { p <- ctx$pilot; h <- hfun_of(p); Sc <- build_graded(p, h)
  mid <- (head(Sc, -1) + Sc[-1]) / 2; wide <- diff(Sc) > WIDE * vapply(mid, h, 0) + 1e-9
  Sf <- sort(unique(round(c(Sc, mid[wide & p$shut(mid) < 0.5]), 10)))
  c <- ctx$run(Sc); f <- ctx$run(Sf); k <- names(c$q); d <- c$q[k] - f$q[k]
  if (all(abs(4 / 3 * d / ctx$eps(k)) < TAU)) return(list(use = list(Sc), answer = c$q[k], estimate = 4 / 3 * d))
  list(use = list(Sf), answer = f$q[k], estimate = d / 3) }
