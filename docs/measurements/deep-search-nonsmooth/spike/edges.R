# edges.R REF OTHER...: each run's f_hi roots (JTROOT on stderr) grouped into clusters
# (roots into BoundaryCrit, v0 < 0 < v1, no gap over GAP days); for each REF cluster the
# matching cluster in OTHER, the offsets of its first and last root in days, and the share
# of OTHER's roots in that cluster lying outside REF's [first - d, last + d].
GAP <- 1 / 365
roots <- function(f) {
  L <- grep("^JTROOT", readLines(f), value = TRUE)
  x <- do.call(rbind, lapply(strsplit(L, " +"), function(s) as.numeric(s[c(3, 5, 7, 9, 13, 15)])))
  d <- data.frame(t = x[, 1] + x[, 4] * x[, 2], node = x[, 3], into = x[, 5] < 0 & x[, 6] >= 0)
  d[order(d$t), ]
}
clusters <- function(d) {
  d <- d[d$into, ]
  g <- cumsum(c(1, diff(d$t) > GAP))
  data.frame(first = tapply(d$t, g, min), last = tapply(d$t, g, max), n = as.vector(table(g)))
}
a <- commandArgs(TRUE)
ref <- roots(a[1]); cr <- clusters(ref)
big <- cr[cr$n >= 5 & cr$first < 25, ]
cat(sprintf("%s: %d roots, %d into-clusters, %d with >= 5 roots before b = 25; width median %.2f d\n",
            a[1], nrow(ref), nrow(cr), nrow(big), median((big$last - big$first) * 365)))
for (f in a[-1]) {
  o <- roots(f); co <- clusters(o); oi <- o[o$into, ]
  res <- t(sapply(seq_len(nrow(big)), function(i) {
    j <- which.min(abs(co$first - big$first[i]))
    inside <- oi$t >= big$first[i] - 2 / 365 & oi$t <= big$last[i] + 2 / 365
    out <- function(dd) mean(oi$t[inside] < big$first[i] - dd / 365 | oi$t[inside] > big$last[i] + dd / 365)
    c(d_first = (co$first[j] - big$first[i]) * 365, d_last = (co$last[j] - big$last[i]) * 365,
      out0 = out(0), out05 = out(0.05), out1 = out(0.1), out25 = out(0.25))
  }))
  q <- function(x) sprintf("median %.3f, 90%% %.3f, max %.3f", median(abs(x)), quantile(abs(x), 0.9), max(abs(x)))
  cat(sprintf("\n%s: %d roots, %d into-clusters\n  |first offset| d: %s\n  |last offset| d: %s\n",
              f, nrow(o), nrow(co), q(res[, 1]), q(res[, 2])))
  cat(sprintf("  share of its roots outside the reference bracket +- 0 / 0.05 / 0.1 / 0.25 d (mean over clusters): %.3f / %.3f / %.3f / %.3f\n",
              mean(res[, 3], na.rm = TRUE), mean(res[, 4], na.rm = TRUE), mean(res[, 5], na.rm = TRUE), mean(res[, 6], na.rm = TRUE)))
}
