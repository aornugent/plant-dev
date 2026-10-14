# mkfine.R PIN T0 T1 HMAX OUT: PIN's steps with every step ending in (T0, T1] that has no
# soil substeps cut into equal pieces of at most HMAX (yr).
a <- commandArgs(TRUE); s <- readRDS(a[1])$stand; t0 <- as.numeric(a[2]); t1 <- as.numeric(a[3]); hm <- as.numeric(a[4])
tt <- s$times; hh <- s$sizes; is <- s$input_slopes; se <- s$substep_ends
nt <- tt[1]; nh <- hh[1]; ni <- is[1]; ns <- se[1]; cut <- 0
for (i in seq_along(tt)[-1]) {
  h <- tt[i] - tt[i - 1]
  if (tt[i] > t0 && tt[i] <= t1 && h > hm && length(is[[i]]) == 0 && length(se[[i]]) == 0 && isTRUE(all.equal(hh[i], h))) {
    n <- ceiling(h / hm); u <- tt[i - 1] + h * seq_len(n) / n; u[n] <- tt[i]
    nt <- c(nt, u); nh <- c(nh, diff(c(tt[i - 1], u))); ni <- c(ni, rep(list(numeric(0)), n)); ns <- c(ns, rep(list(numeric(0)), n)); cut <- cut + 1
  } else { nt <- c(nt, tt[i]); nh <- c(nh, hh[i]); ni <- c(ni, is[i]); ns <- c(ns, se[i]) }
}
saveRDS(list(stand = list(times = nt, sizes = nh, input_slopes = ni, substep_ends = ns)), a[5])
cat(sprintf("%d steps cut, %d -> %d rows\n", cut, length(tt), length(nt)))
