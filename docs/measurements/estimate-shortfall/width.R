# Per panel of P (dropped node j, span [t[j-1], t[j+1]]): its coarsening move e_P from
# the map on P, against 4 x the bisection move inside that span from the map on B.
# Binned by the span's width in days; square law reads 1.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
pe <- function(x) { b <- nd(x); j <- x$dropped; data.frame(t = x$node_times[j], own = own_drop(b, j) / sum(b$w * b$offspring),
  light = colSums(x$light) / x$stand$J, soil = colSums(x$soil) / x$stand$J) }
for (nm in c("u108e_episodic_p3", "s16_dry_p3")) {
  xp <- run(paste0("ref_", nm)); xb <- run(paste0("rcB_", nm)); if (is.null(xb$soil)) next
  t <- xp$node_times; j <- xp$dropped; a <- pe(xp); bb <- pe(xb)
  lo <- t[j - 1]; hi <- t[j + 1]; k <- findInterval(bb$t, sort(c(lo, hi)))
  pb <- t(sapply(seq_along(j), function(i) { s <- bb$t > lo[i] & bb$t < hi[i]; colSums(bb[s, c("own", "light", "soil")]) }))
  wd <- (hi - lo) * 365; late <- t[j] > 3.7
  g <- cut(wd, c(0, 20, 40, 80, 160, 400, 2e4))
  f <- function(v, sel) tapply(v[sel], g[sel], sum)
  for (part in c("own", "soil")) for (L in c(FALSE, TRUE)) {
    cat(sprintf("%s %s %s: e_P / (4 x (P-B)) by span width (days); sums in eps\n", nm, part, if (L) "late" else "founders"))
    print(round(rbind(eP = f(a[[part]], late == L) / .025, `4PB` = 4 * f(pb[, part], late == L) / .025, ratio = f(a[[part]], late == L) / (4 * f(pb[, part], late == L)), n = table(g[late == L])), 3))
  }
}
