# drive.R TOL TARGET[,TARGET...] [CASE...]: refine_schedule and the uniform ladder for real on
# each case at that tolerance. A case whose next run is not on disk requests it (REQ) and is
# retried on the next pass (drive.sh). Finished cases go to drive_TOL.rds.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R")
a <- commandArgs(TRUE); tol <- as.numeric(a[1]); targets <- as.numeric(strsplit(a[2], ",")[[1]])
todo <- if (length(a) > 2) a[-(1:2)] else c(BANK, HELD)
noise <- if (tol >= 1e-4) 0.024 else as.numeric(Sys.getenv("NOISE", "0.012"))
# The uniform alternative with the same stopping rule, k = 1 (E6's check) up to kmax.
uniform <- function(cs, tol, target, kmax = 3) { cr <- case_of_refine(cs, tol)
  x0 <- cr$run(cr$S0, map = FALSE); runs <- list(un_run(cs, tol, 1)); est <- NULL
  prev <- x0
  for (k in seq_len(kmax)) { if (k > 1) runs[[k]] <- un_run(cs, tol, k)
    est <- (prev$q - runs[[k]]$q) / EPS / (1.6^2 - 1); prev <- runs[[k]]
    if (all(abs(est) < target)) break }
  list(k = k, q = runs[[k]]$q, est = est, rows = vapply(runs, `[[`, 0, "rows"), rows0 = x0$rows, done = all(abs(est) < target)) }
f <- file.path(RO, sprintf("drive_%s%s.rds", tag_of_tol(tol), Sys.getenv("DTAG"))); out <- if (file.exists(f)) readRDS(f) else list(); pend <- 0
for (cs in todo) for (tg in targets) { key <- sprintf("%s@%g", cs, tg)
  res <- tryCatch(list(tool = refine_schedule(case_of_refine(cs, tol), target = tg, noise = noise), uniform = uniform(cs, tol, tg)),
                  need_run = function(e) NULL)
  if (is.null(res)) { pend <- pend + 1; next }
  out[[key]] <- res; h <- res$tool$history
  cat(sprintf("%-14s target %.3g | runs %d (%s) | final nodes %d rows %.0f | est max %.3f | uniform k %d%s\n", cs, tg, nrow(h),
    paste(h$region, collapse = ">"), tail(h$nodes, 1), tail(h$rows, 1), max(abs(res$tool$estimate)), res$uniform$k, if (res$uniform$done) "" else " (not met)")) }
saveRDS(out, f); cat(sprintf("tol %g: %d finished, %d waiting on runs\n", tol, length(out), pend))
