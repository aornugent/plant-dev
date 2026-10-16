# r1_score.R CASE [TAGS...]: each region's error on top of res, read from its refinement run:
# -16/15 (X4 - res), -4/3 (X2 - res), -(B - res) (B resolves, no order assumed), and the sum
# of the given regions against e_res (additivity).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
a <- commandArgs(TRUE); cs <- a[1]; tags <- if (length(a) > 1) a[-1] else c("F2", "B", "O4", "I4", "L4")
base <- rd5(sprintf("cl_res_%s", cs)); er <- err_run(base, cs); cat(sprintf("== %s (res %d nodes)\n", cs, length(base$node_times))); line("e_res", er)
fac <- function(t) { k <- suppressWarnings(as.integer(sub("^[A-Za-z_]+", "", t))); if (is.na(k)) 1 else -k^2 / (k^2 - 1) }
tot <- 0 * er; got <- c()
for (t in tags) { f <- file.path(P5, "runs", sprintf("p5_%s_%s.rds", t, cs)); if (!file.exists(f)) next; x <- readRDS(f); if (is.null(x$stand$elasticity)) next
  v <- fac(t) * mv_run(x, base)[names(er)]; line(sprintf("%s (%d, x%.3f)", t, length(x$node_times), fac(t)), v); if (!grepl("^(I[abc]|Os|O1)", t)) { tot <- tot + v; got <- c(got, t) } }
if (length(got)) { line(paste("sum", paste(got, collapse = "+")), tot); line("e_res - sum", er - tot) }
