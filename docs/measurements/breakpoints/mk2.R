# Edge-aligned ladder without closed-gap nodes: base times (uN or rds) plus the
# edges of an edge-source run, then two nested bisections.  Rscript mk2.R EDGE_RUN BASE TAG
args <- commandArgs(TRUE); cr <- readRDS(args[1])$stand$creation; base <- args[2]; tag <- args[3]
s <- if (grepl("^u[0-9]+$", base)) { n <- as.integer(sub("u", "", base)); seq(0, (n - 1) * 40 / n, length.out = n) } else readRDS(base)
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]; ed <- ed[ed > 0 & ed < max(s)]
shut <- approxfun(c(cr$start, tail(cr$end, 1)), c(as.numeric(!op), tail(as.numeric(!op), 1)), method = "constant", rule = 2)
clean <- function(v) { v <- sort(unique(v)); v[c(TRUE, diff(v) > 1e-6)] }
bis <- function(v) clean(c(v, head(v, -1) + diff(v) / 2))
g <- clean(c(s[shut(s) < 0.5], ed)); saveRDS(g, paste0(tag, ".rds")); saveRDS(bis(g), paste0(tag, "2.rds")); saveRDS(bis(bis(g)), paste0(tag, "4.rds"))
cat(sprintf("%s: %d base, %d edges -> %d / %d / %d nodes\n", tag, length(s), length(ed), length(g), length(bis(g)), length(bis(bis(g)))))
