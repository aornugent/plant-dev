# Part 2 read-out: how the refinement criterion rescales between coordinates,
# measured on the same physical state.
a <- commandArgs(TRUE); model <- a[1]
d <- readRDS(sprintf("/home/user/plant-dev/probes/out/46-scale-%s.rds", model))
for (arm in unique(d$tag)) {
  s <- d[d$tag == arm, ]
  cat(sprintf("\n=== %s / %s : per-snapshot ratio E_h/E_t ===\n", model, arm))
  for (t in sort(unique(round(s$time, 3)))) {
    ss <- s[round(s$time, 3) == t, ]
    r <- ss$E_h / ss$E_t; r <- r[is.finite(r) & r > 0]
    if (!length(r)) next
    cat(sprintf(" t=%8.3f  n=%4d  maxE_h=%9.3g maxE_t=%9.3g  ratio: q10=%8.3g med=%8.3g q90=%8.3g\n",
                t, nrow(ss), max(ss$E_h[is.finite(ss$E_h)]), max(ss$E_t[is.finite(ss$E_t)]),
                quantile(r, .1), median(r), quantile(r, .9)))
  }
  mh <- tapply(s$E_h, s$node, function(x) suppressWarnings(max(x[is.finite(x)])))
  mt <- tapply(s$E_t, s$node, function(x) suppressWarnings(max(x[is.finite(x)])))
  tj <- tapply(s$t, s$node, function(x) x[1])
  ok <- is.finite(mh) & is.finite(mt) & mh > 0 & mt > 0
  mh <- mh[ok]; mt <- mt[ok]; tj <- tj[ok]
  cat(sprintf("--- %s: per-node running max (what refinement actually accumulates) ---\n", arm))
  g <- cut(tj, c(0, 0.1, 1, 5, 20, 60, 1e4), include.lowest = TRUE)
  for (lv in levels(g)) {
    i <- which(g == lv); if (!length(i)) next
    cat(sprintf("  t_intro %-12s n=%3d  max E_h=%9.3g  max E_t=%9.3g  med ratio=%9.3g\n",
                lv, length(i), max(mh[i]), max(mt[i]), median(mh[i] / mt[i])))
  }
  for (eps in c(0.2, 0.02, 0.002)) cat(sprintf("  eps=%-8g flagged by E_h: %3d   by E_t: %3d\n",
                                               eps, sum(mh > eps), sum(mt > eps)))
  cat(sprintf("  cohort crossings (dh<0 between neighbouring nodes): %d of %d\n",
              sum(s$dh < 0, na.rm = TRUE), sum(!is.na(s$dh))))
  cat(sprintf("  growth rate g over nodes: min=%.3g max=%.3g ratio=%.3g\n",
              min(s$g[s$g > 0]), max(s$g), max(s$g) / min(s$g[s$g > 0])))
}
