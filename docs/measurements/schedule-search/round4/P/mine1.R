# Saved pairs that differ only in edges: lattice t2 (edges) vs t2ne (none), and c05's noedge probes.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
rd <- function(n) readRDS(file.path(R, paste0(n, ".rds")))
cmp <- function(a, b, case) { x <- rd(a); y <- rd(b); ref <- refq(case); qa <- quantities(x); qb <- quantities(y); k <- Reduce(intersect, list(names(ref), names(qa), names(qb))); e <- eps_vec(k)
  ea <- (qa[k] - ref[k]) / e; eb <- (qb[k] - ref[k]) / e; mv <- eb - ea
  sa <- x$node_times; sb <- y$node_times
  cat(sprintf("%-26s -> %-28s nodes %3d -> %3d rows %.0f -> %.0f | err worst %.2f -> %.2f rms %.3f -> %.3f | move max %.2f (%s) rms %.3f n>0.1 %d | lnJ %.3f -> %.3f\n", a, b, length(sa), length(sb), x$stand$rows/1e3, y$stand$rows/1e3,
    max(abs(ea)), max(abs(eb)), sqrt(mean(ea^2)), sqrt(mean(eb^2)), max(abs(mv)), k[which.max(abs(mv))], sqrt(mean(mv^2)), sum(abs(mv) > 0.1), ea["lnJ"], eb["lnJ"]))
  invisible(list(ea = ea, eb = eb, x = x, y = y)) }
for (cs in c("dry", "episodic")) for (fl in c("f22_l70", "f26_l59.231")) cmp(sprintf("t2_%s_%s", cs, fl), sprintf("t2ne_%s_%s", cs, fl), cs)
x <- rd("t2_dry_f22_l70"); print(x$setting)
for (cs in c("dry", "episodic")) for (v in c("noedge", "noedge25", "noedge30")) cmp(sprintf("val_c5g_c_%s", cs), sprintf("val_probe_%s_%s", v, cs), cs)
print(rd("val_probe_noedge_dry")$setting)
