# Panel by panel: the drop map's estimate of P's error, plain (e/3) and with the
# panel's geometry (e g(l)), against the bisection's honest error, 4/3 (P - B) inside
# the panel's span, binned by the dropped node's position l and by span. Sums in eps.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
pe <- function(x) { b <- nd(x); j <- x$dropped; data.frame(t = x$node_times[j], e = own_drop(b, j) / sum(b$w * b$offspring) + colSums(x$light + x$soil) / x$stand$J) }
for (nm in c("u108e_episodic_p3", "s16_dry_p3")) {
  xp <- run(paste0("ref_", nm)); xb <- run(paste0("rcB_", nm)); t <- xp$node_times; j <- xp$dropped; a <- pe(xp); bb <- pe(xb)
  lo <- t[j - 1]; hi <- t[j + 1]; l <- (t[j] - lo) / (hi - lo); g <- (l^3 + (1 - l)^3) / (3 * l * (1 - l))
  truth <- 4 / 3 * sapply(seq_along(j), function(i) sum(bb$e[bb$t > lo[i] & bb$t < hi[i]]))
  lp <- cut(pmin(l, 1 - l), c(0, 0.05, 0.2, 0.35, 0.5)); sp <- cut((hi - lo) * 365, c(0, 80, 160, 2e4))
  cat(sprintf("\n%s: total truth %+.3f | plain %+.3f | geometric %+.3f eps\n", nm, sum(truth) / .025, sum(a$e) / 3 / .025, sum(a$e * g) / .025))
  for (grp in list(position = lp, span_days = sp)) print(round(rbind(n = table(grp), truth = tapply(truth, grp, sum) / .025, plain = tapply(a$e / 3, grp, sum) / .025,
    geometric = tapply(a$e * g, grp, sum) / .025, abs_err_plain = tapply(abs(a$e / 3 - truth), grp, sum) / .025, abs_err_geom = tapply(abs(a$e * g - truth), grp, sum) / .025), 3))
}
cat("\n== central panels (l > 0.35) by span\n")
for (nm in c("u108e_episodic_p3", "s16_dry_p3")) {
  xp <- run(paste0("ref_", nm)); xb <- run(paste0("rcB_", nm)); t <- xp$node_times; j <- xp$dropped; a <- pe(xp); bb <- pe(xb)
  lo <- t[j - 1]; hi <- t[j + 1]; l <- (t[j] - lo) / (hi - lo)
  truth <- 4 / 3 * sapply(seq_along(j), function(i) sum(bb$e[bb$t > lo[i] & bb$t < hi[i]]))
  c <- pmin(l, 1 - l) > 0.35; sp <- cut((hi - lo) * 365, c(0, 80, 160, 300, 2e4))
  cat(nm, "\n"); print(round(rbind(n = table(sp[c]), truth = tapply(truth[c], sp[c], sum) / .025, plain = tapply(a$e[c] / 3, sp[c], sum) / .025), 3)) }
