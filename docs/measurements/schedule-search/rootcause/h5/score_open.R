# score_open.R CASE: O2, the opening-inset ladder at s = 1 under H5's closing treatment.
# e(d) = Q(oin_d) - Q(ores), eps units.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/score_lib.R")
cs <- commandArgs(TRUE)[1]; ref <- ref5(cs)
r <- lapply(c(o24 = "oin24", o12 = "oin12", o6 = "oin6", res = "ores"), function(k) h5_run(sprintf("h5_%s_%s", k, cs)))
for (k in names(r)) if (!is.null(r[[k]])) cat(sprintf("%-4s n %3d rows %6.0f cpu %5.0f | err vs ref: %s\n", k, length(r[[k]]$node_times), rows_of(r[[k]]), cpu_of(r[[k]]), fmt1(err_of(r[[k]], ref))))
if (is.null(r$res)) quit()
e <- lapply(r[c("o24", "o12", "o6")], function(x) if (!is.null(x)) mv(x, r$res))
for (k in names(e)) if (!is.null(e[[k]])) cat(sprintf("e(%s) = Q - Q(ores): %s\n", k, fmt1(e[[k]])))
if (!is.null(e$o24) && !is.null(e$o12)) cat(sprintf("e24 on e12: projected %.2f (law 4), cos %.2f, rms ratio %.2f, root_P50 ratio %.2f, M ratio %.2f\n",
  proj(e$o24, e$o12), cosv(e$o24, e$o12), r2(e$o24) / r2(e$o12), e$o24["root_P50"] / e$o12["root_P50"], onM(e$o24) / onM(e$o12)))
if (!is.null(e$o6) && !is.null(e$o12)) cat(sprintf("e6 on e12: projected %.2f (law 0.25), cos %.2f, rms ratio %.2f; moves d1 = o24 - o12, d2 = o12 - o6: projected %.2f (law 4), cos %.2f\n",
  proj(e$o6, e$o12), cosv(e$o6, e$o12), r2(e$o6) / r2(e$o12), if (!is.null(e$o24)) proj(e$o24 - e$o12, e$o12 - e$o6) else NA, if (!is.null(e$o24)) cosv(e$o24 - e$o12, e$o12 - e$o6) else NA))
saveRDS(e, file.path(H5, sprintf("open_%s.rds", cs)))
