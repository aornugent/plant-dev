# upair.R TOL CASE...: S1's error read by E6's pair (E1, S0 -> S1) and by the next uniform
# pair up (E1' = (Q1 - Q2u) r^2/(r^2 - 1), S1 -> S2u), against S1's true error; S2u's own
# error and its pair estimate (Q1 - Q2u)/(r^2 - 1).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R")
a <- commandArgs(TRUE); tol <- as.numeric(a[1]); r2 <- 1.6^2
cosv <- function(x, y) sum(x * y) / sqrt(sum(x^2) * sum(y^2))
for (cs in a[-1]) { cr <- case_of_refine(cs, tol); R <- ref_ladder(cs); REQ <- tempfile()
  x0 <- cr$run(cr$S0, FALSE); x1 <- cr$run(cr$S1, FALSE); x2 <- tryCatch(un_run(cs, tol, 2), need_run = function(e) NULL); if (is.null(x2)) next
  e1 <- (x1$q - R$ref) / EPS; e2 <- (x2$q - R$ref) / EPS; E1 <- (x0$q - x1$q) / EPS / (r2 - 1); E1p <- (x1$q - x2$q) / EPS * r2 / (r2 - 1); E2 <- E1p / r2
  rd <- function(est, err) median((est / err)[abs(err) > 0.05])
  cat(sprintf("%-14s S1 W %.3f | E1 max %.3f cos %.2f read %.2f | E1' max %.3f cos %.2f read %.2f | S2u W %.3f (rows %.0f) est max %.3f cos %.2f read %.2f\n",
    cs, max(abs(e1)), max(abs(E1)), cosv(E1, e1), rd(E1, e1), max(abs(E1p)), cosv(E1p, e1), rd(E1p, e1), max(abs(e2)), x2$rows, max(abs(E2)), cosv(E2, e2), rd(E2, e2))) }
