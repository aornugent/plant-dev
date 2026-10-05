# The fifteenth extension's run, as inproc_timing.log reads it.
#   Rscript inproc_report.R run.rds
o <- readRDS(commandArgs(TRUE)[1])
cat(sprintf("J: split %.12f, plain %.12f\n", o$J$split, o$J$plain))
for (a in names(o$forward)) {
  f <- o$forward[[a]]
  cat(sprintf("%s's stand: %.1f s, %.1f s CPU, %.0f MB\n", a, f$secs, f$cpu_secs, f$rss_mb))
}
d <- do.call(rbind, lapply(o$sweeps, as.data.frame))
for (i in seq_len(nrow(d))) {
  cat(sprintf("sweep %d, %s: %.1f s, %.1f s CPU, peak %.0f MB, d J / d lma %.10f\n", i,
              d$arm[i], d$secs[i], d$cpu_secs[i], d$peak_mb[i], d$lma[i]))
}
s <- d[d$arm == "split", ]
p <- d[d$arm == "plain", ]
for (what in c("secs", "cpu_secs")) {
  pairs <- s[[what]] / p[[what]] - 1
  cat(sprintf("on %s: pairs %s; their mean %+.1f%%, sd %.1f%%; the means' ratio %+.1f%%\n",
              what, paste(sprintf("%+.1f%%", 100 * pairs), collapse = ", "),
              100 * mean(pairs), 100 * sd(pairs),
              100 * (mean(s[[what]]) / mean(p[[what]]) - 1)))
}
