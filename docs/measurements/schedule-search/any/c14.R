# c10 committing L up to 0.88.
# c06 with A's estimate read mostly from the difference with the fine check C, adding C's
# own small error from the L-C pair: est(A) = (QA - QC) + rc/(1 - rc) (QL - QC). The predicted
# ratio only scales C's small error, and the noise of C enters once instead of amplified.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/search/any/learnbuild/lib.R")
RC <- 0.2; TL <- 0.88; GOAL <- 0.78
one <- function(b) rep(1, length(b))
algorithm <- function(ctx) { p <- ctx$pilot
  g <- coarse(p, 1); a <- ctx$run(g$S, drop = g$drop); d <- dlin(g$S, g$drop, a$map)
  XL <- Xpred(g$S, d, p); PG <- prep(p, d, one); C <- build_rho(p, d, XL, RC, one, PG = PG)
  c <- ctx$run(C$S); k <- names(a$q); e <- ctx$eps(k); rc <- sum(Xpred(C$S, d, p)) / sum(XL)
  estC <- rc / (1 - rc) * (a$q[k] - c$q[k]); estL <- a$q[k] - c$q[k] + estC
  if (all(abs(estL / e) < TL)) return(list(use = list(g$S), answer = a$q[k], estimate = estL))
  rA <- min(0.9, GOAL / max(abs(estL / e))); A <- build_rho(p, d, XL, rA, one, PG = PG)
  b <- ctx$run(A$S)
  list(use = list(A$S), answer = b$q[k], estimate = b$q[k] - c$q[k] + estC) }
