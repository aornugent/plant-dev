# Every saved map run: its record, trait setting and how many dropped nodes are pilot edges.
source("/home/user/plant-dev/harness/schedule/lattice.R")
A <- file.path(DEV, "schedtest/adjmap/runs")
x <- readRDS(file.path(A, "loc_G0_episodic-lma.rds")); print(x$setting$env)
PE <- list(); for (cs in names(CASES)) PE[[cs]] <- pilot_edges(cs)
out <- list()
for (f in list.files(A, "\\.rds$")) { y <- tryCatch(readRDS(file.path(A, f)), error = function(e) NULL)
  if (is.null(y) || !identical(y$mode, "map") || !length(y$dropped)) next
  env <- y$setting$env; tr <- if (!is.null(env["TRAITS"]) && !is.na(env["TRAITS"])) env["TRAITS"] else ""
  reg <- y$setting$regime; cs <- if (reg %in% names(CASES)) reg else NA
  if (grepl("lma", f) || grepl("lma", tr)) cs <- if (reg == "episodic") "episodic-lma" else NA
  if (is.na(cs) || is.null(PE[[cs]])) { cat(f, reg, tr, "no case\n"); next }
  S <- y$node_times; isE <- vapply(S, function(s) min(abs(PE[[cs]]$edges - s)) < 1e-6, TRUE)
  out[[f]] <- data.frame(f = f, case = cs, tr = tr, n = length(S), nE = sum(isE), drop = length(y$dropped), dropE = sum(isE[y$dropped]), dropE25 = sum(isE[y$dropped] & S[y$dropped] < 25))
}
o <- do.call(rbind, out); print(o[o$dropE > 0, ], row.names = FALSE)
