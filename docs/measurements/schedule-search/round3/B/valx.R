# A thinned committed run against an unthinned check, scored as val.R scores a pair:
#   Rscript valx.R COMMITTED_PREFIX CHECK_PREFIX CASE...  (files <prefix>_<case>.rds in adjmap/runs)
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max"); R <- AR; a <- commandArgs(TRUE)
alg <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a05_fill.R", alg)
pilot_of <- function(case) { cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
  list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")])) }
refq <- function(case) if (!is.null(CASES[[case]])) reference(case) else {
  x <- quantities(readRDS(file.path(R, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(R, sprintf("ref_%s_u429.rds", case))))
  k <- intersect(names(x), names(y)); extrap(x[k], y[k]) }
for (case in a[-(1:2)]) { fc <- file.path(R, sprintf("%s_%s.rds", a[1], case)); ff <- file.path(R, sprintf("%s_%s.rds", a[2], case))
  if (!file.exists(fc) || !file.exists(ff)) { cat(case, ": missing\n"); next }
  xc <- readRDS(fc); xf <- readRDS(ff); ref <- refq(case); qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k)
  ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e; d <- (qc[k] - qf[k]) / e; p <- pilot_of(case); sh <- alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times)
  coarse <- all(abs(d / (1 - sh)) < 1); err <- if (coarse) ec else ef; sest <- if (coarse) d / (1 - sh) else d * sh / (1 - sh); est <- abs(sest)
  big <- pmax(abs(err), est) > 1 / 3; ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  C1 <- all(abs(err) <= 1); C2 <- all(est[abs(err) > 0.5] > 0.25); C3 <- if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE; C5 <- all(est <= 1)
  cost <- run_cost(xc$stand$rows, TRUE) + run_cost(xf$stand$rows, TRUE); use <- run_cost((if (coarse) xc else xf)$stand$rows, TRUE)
  rc <- d / (1 - sh) / ec; w <- which.max(abs(d / (1 - sh)))
  cat(sprintf("%-20s %-13s s %.3f commit %-6s | worst %.2f (%s) | coarse worst err %.2f, its largest estimate %.2f (%s) | C1 %d C2 %d C3 %d (%d/%d) C5 %d | read median %.2f | T %.0f\n",
    a[1], case, sh, if (coarse) "coarse" else "fine", max(abs(err)), k[which.max(abs(err))], max(abs(ec)), abs(d / (1 - sh))[w], k[w], C1, C2, C3, sum(ok3), sum(big), C5,
    median(rc[abs(ec) > 0.2]), cost + 2 * use)) }
