# run_loop.R RESERVE [CASE...]: the schedule loop for real on each case (runs from disk when
# that exact schedule has run, otherwise launched); writes loop_RESERVE.rds.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/loop_run.R")
a <- commandArgs(TRUE); reserve <- as.numeric(a[1]); todo <- if (length(a) > 1) a[-1] else c(BANK, HELD)
f <- file.path(LO, sprintf("loop_%.2f.rds", reserve)); out <- if (file.exists(f)) readRDS(f) else list()
lg <- file.path(LO, sprintf("loop_%.2f.log", reserve))
for (cs in todo) { cat(sprintf("%s %s\n", cs, format(Sys.time(), "%T")), file = lg, append = TRUE)
  res <- schedule_loop(real_run(cs, lg), EPS, sel_scale_of(cs), reserve = reserve)
  out[[cs]] <- res; saveRDS(out, f)
  cat(sprintf("%-14s pred %.2f | runs %s | final s %.3f%s | est max %.2f\n", cs, res$predicted, paste(sprintf("%.3f", res$runs$s), collapse = " "), res$s, if (res$cap) " (cap)" else "", max(abs(res$est)))) }
