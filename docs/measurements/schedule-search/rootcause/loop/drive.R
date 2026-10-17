# drive.R ROUTE RESERVE [CASE...]: the loop for real on each case, ROUTE "A" (E6+ one scale,
# schedule_loop) or "B" (U with one scale per region, allocation_loop). A case whose next run
# is not on disk requests it (requests.txt) and is retried on the next pass (drive.sh).
# Finished cases are written to loopA_RESERVE.rds / loopB_RESERVE.rds.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/loop_run.R")
a <- commandArgs(TRUE); route <- a[1]; reserve <- as.numeric(a[2]); todo <- if (length(a) > 2) a[-(1:2)] else c(BANK, HELD)
f <- file.path(LO, sprintf("loop%s_%.2f.rds", route, reserve)); out <- list(); pend <- 0
for (cs in todo) {
  res <- tryCatch(if (route == "A") schedule_loop(ep_request(cs), EPS, sel_scale_of(cs), reserve = reserve)
                  else allocation_loop(rb_request(cs), EPS, sel_scale_of(cs), RB_REG, reserve = reserve),
                  need_run = function(e) NULL)
  if (is.null(res)) { pend <- pend + 1; next }
  out[[cs]] <- res
  cat(sprintf("%-14s pred %.2f | runs %d | final %s%s | est max %.2f\n", cs, res$predicted, nrow(res$runs),
    if (route == "A") sprintf("s %.3f", res$s) else paste(sprintf("%.2f", res$sv), collapse = "/"), if (res$cap) " (cap)" else "", max(abs(res$est)))) }
saveRDS(out, f); cat(sprintf("route %s reserve %.2f: %d finished, %d waiting on runs\n", route, reserve, length(out), pend))
