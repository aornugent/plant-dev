# For a grid P and its first pass: B (bisection), Cp (drop every other non-edge node),
# Co (drop every other node).  Rscript mkcb.R GRID.rds FIRST_PASS.rds TAG
a <- commandArgs(TRUE); p <- readRDS(a[1]); cr <- readRDS(a[2])$stand$creation; tag <- a[3]
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/rc"
op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); ed <- cr$end[e][-length(e)]
keep <- round(p, 9) %in% round(ed, 9) | seq_along(p) %in% c(1, length(p)); free <- which(!keep)
saveRDS(p, file.path(S, paste0(tag, "_P.rds"))); saveRDS(sort(c(p, head(p, -1) + diff(p) / 2)), file.path(S, paste0(tag, "_B.rds")))
saveRDS(p[-free[seq(2, length(free), by = 2)]], file.path(S, paste0(tag, "_Cp.rds"))); saveRDS(p[-seq(2, length(p) - 1, by = 2)], file.path(S, paste0(tag, "_Co.rds")))
cat(tag, length(p), "nodes,", sum(keep), "edges kept\n")
