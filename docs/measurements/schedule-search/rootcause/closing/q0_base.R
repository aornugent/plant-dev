# q0_base.R: the saved runs' errors (eps) on the four cases: committed (insk c, 12 d inset),
# check (ins75 f, 7.5 d), coarse companion (insx x, 19.2 d) and its 12-d diagnostic (insx12).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
for (cs in c("dry", "dry-p50", "dry-flat", "long-wet", "wet-adG2")) {
  for (nm in c(sprintf("val_insx_x_%s", cs), sprintf("val_insx12_x_%s", cs), sprintf("val_insk_c_%s", cs), sprintf("val_ins75_f_%s", cs))) {
    f <- tryCatch(run_file(nm), error = function(e) NA); if (is.na(f)) next; x <- readRDS(f); e <- err_run(x, cs)
    top <- names(e)[order(-abs(e))][1:4]
    cat(sprintf("%-9s %-22s n %3d | rms %.3f worst %.2f | along M %+.2f off-M %.3f | lnJ %+.3f | %s\n", cs, nm, length(x$node_times), r2(e), max(abs(e)), onM(e), offM(e), e["lnJ"],
      paste(sprintf("%s %+.2f", top, e[top]), collapse = ", "))) } }
