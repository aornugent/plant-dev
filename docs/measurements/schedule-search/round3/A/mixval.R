# Scores a09's decision rule on saved runs, with the committed and check runs taken from
# any two tags (so at any two tolerances), as loc/val.R does for one tag.
#   Rscript mixval.R COMMIT_TAG CHECK_TAG [CASE...]
# Each line also splits the committed run's estimate into its node part (a09's own pair
# at 1e-4) and its tolerance part (the committed schedule's move from 1e-4 to COMMIT_TAG).
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max")
a <- commandArgs(TRUE); tc <- a[1]; tf <- a[2]; cases <- if (length(a) > 2) a[-(1:2)] else names(CASES)
alg <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a09_late.R", alg)
pilot_of <- function(case) { cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
  list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")])) }
refq <- function(case) if (!is.null(CASES[[case]])) reference(case) else {
  x <- quantities(readRDS(file.path(AR, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(AR, sprintf("ref_%s_u429.rds", case))))
  k <- intersect(names(x), names(y)); extrap(x[k], y[k]) }
ld <- function(tag, r, case) { f <- file.path(AR, sprintf("val_%s_%s_%s.rds", tag, r, case)); if (!file.exists(f)) return(NULL); x <- readRDS(f)
  if (is.null(x$stand$elasticity) || !all(is.finite(x$stand$elasticity))) return(NULL); x }
TOT <- 0
for (case in cases) { xc <- ld(tc, "c", case); xf <- ld(tf, "f", case); x0 <- ld("a09", "c", case)
  if (is.null(xc) || is.null(xf)) { cat(sprintf("%-13s runs missing or incomplete\n", case)); next }
  ref <- refq(case); qc <- quantities(xc); qf <- quantities(xf); q0 <- quantities(x0)
  k <- Reduce(intersect, list(names(ref), names(qc), names(qf), names(q0))); e <- eps_vec(k)
  ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e; d <- (qc[k] - qf[k]) / e
  p <- pilot_of(case); sh <- alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times)
  coarse <- all(abs(d / (1 - sh)) < 1); err <- if (coarse) ec else ef; sest <- if (coarse) d / (1 - sh) else d * sh / (1 - sh); est <- abs(sest)
  big <- pmax(abs(err), est) > 1 / 3; ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  C1 <- all(abs(err) <= 1); C2 <- all(est[abs(err) > 0.5] > 0.25); C3 <- if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE; C5 <- all(est <= 1)
  use <- run_cost((if (coarse) xc else xf)$stand$rows, TRUE); T <- run_cost(xc$stand$rows, TRUE) + run_cost(xf$stand$rows, TRUE) + 2 * use; TOT <- TOT + T
  tolp <- (qc[k] - q0[k]) / e
  cat(sprintf("%-13s s %.2f commit %-6s | worst %.2f (%s) | C1 %d C2 %d C3 %d (%d/%d) C5 %d | max|est| %.2f | est/err median %.2f | T %.0f | committed's tol move max %.2f\n",
    case, sh, if (coarse) "coarse" else "fine", max(abs(err)), k[which.max(abs(err))], C1, C2, C3, sum(ok3), sum(big), C5, max(est),
    median((d / (1 - sh) / ec)[abs(ec) > 0.2]), T, max(abs(tolp))))
  o <- head(order(-pmax(abs(err), est)), 6)
  for (i in o) cat(sprintf("     %-26s err %+.2f est %+.2f | committed err %+.2f, of it tol move %+.2f\n", k[i], err[i], sest[i], ec[i], tolp[i])) }
cat(sprintf("T over these cases: %.0f\n", TOT))
