# mkstops.R PIN OUT T1 ... Tn: PIN's steps with the boundaries between T1 and Tn replaced
# by exactly T1..Tn (steps there have no soil substeps), so two runs given the same Ti take
# identical steps over [T1, Tn] and their own steps elsewhere.
a <- commandArgs(TRUE); s <- readRDS(a[1])$stand; cuts <- sort(as.numeric(a[-(1:2)]))
tt <- s$times; keep <- !(tt > cuts[1] - 1e-9 & tt < tail(cuts, 1) + 1e-9)
inside <- which(!keep); stopifnot(all(lengths(s$input_slopes[inside]) == 0), all(lengths(s$substep_ends[inside]) == 0))
nt <- sort(c(tt[keep], cuts)); idx <- match(nt, tt)
sz <- c(s$sizes[1], diff(nt)); old <- !is.na(idx) & c(FALSE, !is.na(idx[-1]) & !is.na(idx[-length(idx)]))
sz[old] <- s$sizes[idx[old]]  # keep recorded sizes (h = 0 rows) where neighbours are unchanged
ni <- lapply(seq_along(nt), function(i) if (is.na(idx[i]) || (i > 1 && is.na(idx[i - 1]))) numeric(0) else s$input_slopes[[idx[i]]])
ns <- lapply(seq_along(nt), function(i) if (is.na(idx[i]) || (i > 1 && is.na(idx[i - 1]))) numeric(0) else s$substep_ends[[idx[i]]])
saveRDS(list(stand = list(times = nt, sizes = sz, input_slopes = ni, substep_ends = ns)), a[2])
w <- nt > 9.68 & nt < 9.715; cat("steps in 9.68-9.715:", round(nt[w], 5), "| sizes (d):", round(sz[w] * 365, 2), "\n")
