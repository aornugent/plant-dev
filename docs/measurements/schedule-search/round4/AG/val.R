# val.R CASE...: on each case, a09's pair and the inset pair scored as loc/val.R scores
# (ALG a09_late's shrink from the pilot proxy, R = 1.6, C1-C5), on both gates: lib19
# runs against lib19 references, libAG runs (AG_a09c/f, AG_insc/f) against the libAG
# reference. The gate's window column is set aside (both gates score the same set).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
M19 <- function(cs, k) { x <- tryCatch({ a <- quantities(ag_run(sprintf("P_in10_%s", cs))); b <- quantities(rd_run("a09", "c", cs)); (a[k] - b[k]) / eps_vec(k) }, error = function(e) NULL); x }
for (cs in commandArgs(TRUE)) {
  r19 <- refq(cs); rAG <- tryCatch(ref_ag(cs), error = function(e) NULL)
  pairs <- list(lib19_a09 = list(rd_run("a09", "c", cs), rd_run("a09", "f", cs), r19),
                lib19_ins = list(tryCatch(ag_run(sprintf("P_insc_%s", cs)), error = function(e) NULL), tryCatch(ag_run(sprintf("P_insf_%s", cs)), error = function(e) NULL), r19),
                libAG_a09 = list(tryCatch(ag_run(sprintf("AG_a09c_%s", cs)), error = function(e) NULL), tryCatch(ag_run(sprintf("AG_a09f_%s", cs)), error = function(e) NULL), rAG),
                libAG_ins = list(tryCatch(ag_run(sprintf("AG_insc_%s", cs)), error = function(e) NULL), tryCatch(ag_run(sprintf("AG_insf_%s", cs)), error = function(e) NULL), rAG))
  if (!is.null(rAG)) cat(sprintf("%s libAG reference own estimate %.2f eps\n", cs, attr(rAG, "own")))
  for (nm in names(pairs)) { p <- pairs[[nm]]; if (is.null(p[[1]]) || is.null(p[[3]])) next
    if (is.null(p[[2]])) { e <- err_of(p[[1]], p[[3]]); m <- M19(cs, names(e))
      cat(sprintf("%-13s %-9s c only: worst %.2f (%s) rms %.3f lnJ %+.3f%s\n", cs, nm, max(abs(e)), names(e)[which.max(abs(e))], sqrt(mean(e^2)), e["lnJ"], if (is.null(m)) "" else sprintf(" | on -M19 %.2f", -sum(e * m) / sum(m^2)))); next }
    z <- score_pair(cs, p[[1]], p[[2]], p[[3]]); m <- M19(cs, z$k)
    cat(fmt_pair(cs, nm, z), if (is.null(m)) "" else sprintf(" | c on -M19 %.2f f %.2f", -sum(z$ec * m) / sum(m^2), -sum(z$ef * m) / sum(m^2)), "\n") } }
