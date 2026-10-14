# Shared loaders for agent AG: P's (and F's) helpers, plus runs on libAG (the averaged
# gate), their references, and scoring as loc/val.R scores (ALG = a09_late.R, the
# shrink from the lib19 pilot's proxy, R = 1.6).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
AGOUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/AG_out"
AGR <- file.path(AGOUT, "runs")
# The gate's own window column is set aside so both gates score the same quantities;
# its error is reported on its own.
EXCLUDED <<- c(EXCLUDED, "establishment_window")
ag_run <- function(nm) { f <- file.path(AGR, paste0(nm, ".rds")); if (!file.exists(f)) f <- file.path(POUT, "runs", paste0(nm, ".rds")); if (!file.exists(f)) f <- file.path(R, paste0(nm, ".rds"))
  x <- readRDS(f); if (is.null(x$stand$elasticity)) stop(nm, ": no gradient"); x }
q_win <- function(x) { e <- x$stand$elasticity; unname(e[grepl("establishment_window", names(e))]) }
# The libAG reference: u215 and u429 extrapolated on the square law, as anyscore's extrap().
ref_ag <- function(case) { a <- ag_run(sprintf("AG_ref_%s_u215", case)); b <- ag_run(sprintf("AG_ref_%s_u429", case))
  x <- quantities(a); y <- quantities(b); k <- intersect(names(x), names(y)); r <- extrap(x[k], y[k])
  attr(r, "own") <- max(abs((y[k] - x[k]) / 3 / eps_vec(k))); attr(r, "win") <- q_win(b) + (q_win(b) - q_win(a)) / 3; r }
# Errors of a run against a reference, in eps.
err_of <- function(x, ref) { q <- quantities(x); k <- intersect(names(ref), names(q)); (q[k] - ref[k]) / eps_vec(k) }
# A committed (c) and check (f) run scored as loc/val.R scores them.
score_pair <- function(cs, xc, xf, ref) { qc <- quantities(xc); qf <- quantities(xf); k <- Reduce(intersect, list(names(ref), names(qc), names(qf))); e <- eps_vec(k)
  ec <- (qc[k] - ref[k]) / e; ef <- (qf[k] - ref[k]) / e; d <- (qc[k] - qf[k]) / e; p <- pilot_of(cs); sh <- alg$proxy_err(p, xf$node_times) / alg$proxy_err(p, xc$node_times)
  coarse <- all(abs(d / (1 - sh)) < 1); err <- if (coarse) ec else ef; sest <- if (coarse) d / (1 - sh) else d * sh / (1 - sh); cr <- crit(err, sest)
  big <- pmax(abs(err), abs(sest)) > 1 / 3; ok3 <- abs(sest[big]) >= abs(err[big]) / 2 & abs(sest[big]) <= 2 * abs(err[big]) & sign(sest[big]) == sign(err[big])
  rows <- function(x) run_cost(x$stand$rows, TRUE); use <- if (coarse) xc else xf
  list(k = k, ec = ec, ef = ef, est = sest, coarse = coarse, pass = all(cr), cr = cr, n3 = sprintf("%d/%d", sum(ok3), sum(big)), miss = k[big][!ok3],
       worst = max(abs(err)), wq = k[which.max(abs(err))], rms = sqrt(mean(err^2)), cworst = max(abs(ec)), crms = sqrt(mean(ec^2)), fworst = max(abs(ef)), frms = sqrt(mean(ef^2)),
       read = median((d / (1 - sh) / ec)[abs(ec) > 0.2]), corr = cor(d / (1 - sh), ec), s = sh, T = rows(xc) + rows(xf) + 2 * rows(use), Tcpu = cpu_of(xc) + cpu_of(xf) + 2 * cpu_of(use),
       nc = length(xc$node_times), nf = length(xf$node_times)) }
fmt_pair <- function(cs, tag, z) sprintf("%-13s %-8s n %3d/%3d s %.2f | commit %s %s | worst %.2f (%s) rms %.3f | c %.2f/%.3f f %.2f/%.3f | C3 %s%s | read %.2f corr %.2f | T %4.0f cpu %4.0f",
  cs, tag, z$nc, z$nf, z$s, if (z$coarse) "coarse" else "fine  ", if (z$pass) "pass" else paste("FAIL", paste(names(z$cr)[!z$cr], collapse = "")), z$worst, z$wq, z$rms,
  z$cworst, z$crms, z$fworst, z$frms, z$n3, if (length(z$miss)) paste0(" miss ", paste(z$miss, collapse = ",")) else "", z$read, z$corr, z$T, z$Tcpu)
