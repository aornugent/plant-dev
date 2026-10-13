# val.R TAG CASE...: real runs of an algorithm's committed (c) and check (f) schedules
# against each case's reference; the algorithm's decision, C1-C5 (rooting_depth_max set
# aside), cost, and for training cases the scorer's prediction of each run.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max"); NOISE <<- "2"
a <- commandArgs(TRUE); tag <- a[1]; R <- AR
# The committed run's estimate is move/(1 - s) and the check's move*s/(1 - s): s = 1/4
# for a check that halves every interval, else from the algorithm's own shrink or proxy_err (ALG).
alg <- new.env(); if (nzchar(Sys.getenv("ALG"))) sys.source(Sys.getenv("ALG"), alg)
pilot_of <- function(case) { cs <- case_of(case); pe <- pilot_edges(case); px <- readRDS(file.path(RUNS, paste0(cs$pilot, ".rds")))$stand
  list(b1 = pe$b1, edges = pe$edges, shut = pe$shut, nodes = as.data.frame(px$nodes[c("birth", "nrr", "height", "mortality")])) }
refq <- function(case) if (!is.null(CASES[[case]])) reference(case) else {
  x <- quantities(readRDS(file.path(R, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(R, sprintf("ref_%s_u429.rds", case))))
  k <- intersect(names(x), names(y)); extrap(x[k], y[k]) }
refmove <- function(case) if (!is.null(CASES[[case]])) NA else {
  x <- quantities(readRDS(file.path(R, sprintf("ref_%s_u215.rds", case)))); y <- quantities(readRDS(file.path(R, sprintf("ref_%s_u429.rds", case))))
  k <- intersect(names(x), names(y)); max(abs((y[k] - x[k]) / 3 / eps_vec(k))) }
for (case in a[-1]) { fc <- file.path(R, sprintf("val_%s_c_%s.rds", tag, case)); ff <- file.path(R, sprintf("val_%s_f_%s.rds", tag, case))
  if (!file.exists(fc) || !file.exists(ff)) { cat(case, ": runs missing\n"); next }
  xc <- readRDS(fc); xf <- readRDS(ff); if (is.null(xc$stand$elasticity) || is.null(xf$stand$elasticity)) { cat(case, ": runs incomplete\n"); next }
  ref <- refq(case); qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k)
  ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e; d <- (qc[k] - qf[k]) / e
  sh <- if (!is.null(alg$shrink)) alg$shrink(pilot_of(case), xc$node_times, xf$node_times) else
        if (is.null(alg$proxy_err)) 0.25 else { p <- pilot_of(case); alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times) }
  coarse <- all(abs(d / (1 - sh)) < 1); err <- if (coarse) ec else ef; sest <- if (coarse) d / (1 - sh) else d * sh / (1 - sh); est <- abs(sest)
  big <- pmax(abs(err), est) > 1 / 3; ok3 <- est[big] >= abs(err[big]) / 2 & est[big] <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  C1 <- all(abs(err) <= 1); C2 <- all(est[abs(err) > 0.5] > 0.25); C3 <- if (any(big)) sum(!ok3) <= max(1, floor(0.2 * sum(big))) else TRUE; C5 <- all(est <= 1)
  cost <- run_cost(xc$stand$rows, TRUE) + run_cost(xf$stand$rows, TRUE); use <- run_cost((if (coarse) xc else xf)$stand$rows, TRUE)
  cat(sprintf("%-13s commit %s | worst %.2f (%s) | C1 %d C2 %d C3 %d (%d/%d) C5 %d | est/err median %.2f | T %.0f (find %.0f, use %.0f)%s\n",
    case, if (coarse) "coarse" else "fine", max(abs(err)), k[which.max(abs(err))], C1, C2, C3, sum(ok3), sum(big), C5,
    median((d / (1 - sh) / ec)[abs(ec) > 0.2]), cost + 2 * use, cost, use, if (is.na(refmove(case))) "" else sprintf(" | ref's own estimate up to %.2f", refmove(case))))
  if (!is.null(CASES[[case]])) { cd <- prepare(case); STRESS <<- 0
    pc <- sim(cd, xc$node_times, case)$err[k]; pf <- sim(cd, xf$node_times, case)$err[k]
    rows_p <- predict(cd$rowsfit, data.frame(n = c(length(xc$node_times), length(xf$node_times)), life = c(sum(H - xc$node_times), sum(H - xf$node_times))))
    cat(sprintf("%-13s   scorer: rms miss c %.3f, f %.3f (max %.2f); rows real/model %.2f, %.2f\n", "", sqrt(mean((pc - ec)^2)), sqrt(mean((pf - ef)^2)),
      max(abs(c(pc - ec, pf - ef))), xc$stand$rows / rows_p[1], xf$stand$rows / rows_p[2])) } }
