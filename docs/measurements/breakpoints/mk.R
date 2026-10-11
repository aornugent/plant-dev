# Two-pass schedules: a base run's own creation edges added as nodes, nested
# bisections, and a variant without the base's nodes born in a closed gap.
args <- commandArgs(TRUE); base_run <- args[1]; base_times <- args[2]; tag <- args[3]
x <- readRDS(base_run)$stand; cr <- x$creation
s <- if (grepl("^u[0-9]+$", base_times)) { n <- as.integer(sub("u", "", base_times)); seq(0, (n - 1) * 40 / n, length.out = n) } else readRDS(base_times)
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths)
ed <- cr$end[e][-length(e)]; ed <- ed[ed > 0 & ed < max(s)]
shut <- approxfun(c(cr$start, tail(cr$end, 1)), c(as.numeric(!op), tail(as.numeric(!op), 1)), method = "constant", rule = 2)
clean <- function(v) { v <- sort(unique(v)); v[c(TRUE, diff(v) > 1e-6)] }
l <- clean(c(s, ed))
gap <- shut(s) > 0.5 & !(s %in% ed)          # base nodes born while the gate is shut
g <- clean(c(s[!gap], ed))
bis <- function(v) clean(c(v, head(v, -1) + diff(v) / 2))
saveRDS(l, paste0(tag, "e.rds")); saveRDS(bis(l), paste0(tag, "e2.rds")); saveRDS(bis(bis(l)), paste0(tag, "e4.rds"))
saveRDS(g, paste0(tag, "g.rds")); saveRDS(bis(g), paste0(tag, "g2.rds"))
cat(sprintf("%s: %d base nodes, %d edges, %d in closed gaps; e %d / %d / %d; g %d / %d\n", tag, length(s), length(ed), sum(gap),
            length(l), length(bis(l)), length(bis(bis(l))), length(g), length(bis(g))))
