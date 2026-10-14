source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
rd <- function(n) readRDS(file.path(R, paste0(n, ".rds")))
row <- function(n, case, crcase = case) { S <- rd(n)$node_times; A <- anatomy(S[S < 25], crcase); x <- exposure(A)
  cat(sprintf("%-28s on %-8s n %3d proxy %.3e | Xg %.4f Xs %.4f mixed %d\n", n, crcase, length(S), proxy(crcase, S), x[1], x[2], x[3])) }
for (cs in c("dry", "episodic")) for (fl in c("f22_l70", "f26_l59.231")) { row(sprintf("t2_%s_%s", cs, fl), cs); row(sprintf("t2ne_%s_%s", cs, fl), cs) }
for (cs in c("dry", "episodic")) { row(sprintf("val_c5g_c_%s", cs), cs); row(sprintf("val_probe_noedge_%s", cs), cs) }
row("val_a09_c_dry", "dry"); row("val_a09_c_dry", "dry-p50"); row("val_a09_c_dry-p50", "dry-p50")
row("val_a09_c_episodic", "episodic"); row("val_a09_c_episodic", "episodic-lma"); row("val_a09_c_episodic-lma", "episodic-lma")
