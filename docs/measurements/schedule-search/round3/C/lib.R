# Offline helpers for round 3 lens C: the scorer's cost, noise-free errors and per-band
# interval error for any schedule, without running an algorithm.
Sys.setenv(R = Sys.getenv("R", "1.6"), BG = Sys.getenv("BG", "90"))
source("/home/user/plant-dev/harness/schedule/anyscore.R")
A05 <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a05_fill.R", A05)
TRAIN <- names(CASES)
cost_of <- function(cd, S, gradient = TRUE) run_cost(max(1, predict(cd$rowsfit, data.frame(n = length(S), life = sum(H - S)))), gradient)
# Noise-free error of every quantity (in eps) for schedule S.
err_of <- function(cd, S, case) { X <- features(case, S, cd$dens, cd$shut, cd$b1)
  vapply(cd$Qs, function(Q) if (Q == "lnJ") X[["lnJ_signed"]] else { x <- X[-1]; x[is.na(x)] <- 0; sum(cd$kap[[Q]] * x) }, 0) }
bandA <- function(cd, S, case) { X <- features(case, S, cd$dens, cd$shut, cd$b1); x <- X[-1]; x[is.na(x)] <- 0; x }
a05_pair <- function(p) { h <- A05$hfun_of(p); Sc <- build_graded(p, h)
  list(h = h, Sc = Sc, Sk = A05$fill(p, h, Sc, build_graded(p, function(b) h(b) / A05$R))) }
