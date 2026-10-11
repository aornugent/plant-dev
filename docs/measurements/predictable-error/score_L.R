# The late-refined ladder against the placed ladder (episodic).
src <- readLines("../placement/score.R")
eval(parse(text = src[1:grep("^fmt <-", src)]))
Q <- file.path(D, "schedtest", "placed2", "runs")
ref <- { rf <- refs[["episodic"]]; qm <- quantities(rf$m); qf <- quantities(rf$f); k <- intersect(names(qm), names(qf)); extrap(qm[k], qf[k]) }
lad <- list(placed = c("pA", "pA2", "pA4"), late = c("pAL", "pA2L", "pA4L"))
for (nm in names(lad)) {
  o <- lapply(lad[[nm]], function(k) rd(Q, paste0(k, "_episodic"))); q <- lapply(o, quantities)
  k <- Reduce(intersect, c(lapply(q, names), list(names(ref)))); k <- k[!endsWith(k, nuisance)]
  ev <- eps_vec(k); E <- sapply(q, function(v) (v[k] - ref[k]) / ev)
  cat(sprintf("\n== %s ladder: nodes %s, rows %s\n", nm, paste(sapply(o, function(x) length(x$stand$nodes$birth)), collapse = "/"),
              paste(sapply(o, function(x) sprintf("%.0f", rows_of(x))), collapse = "/")))
  cat(sprintf("max |err| (eps) per level: %s; quantities > eps: %s\n", paste(round(apply(abs(E), 2, max), 2), collapse = " / "),
              paste(colSums(abs(E) > 1), collapse = " / ")))
  m1 <- q[[1]][k] - q[[2]][k]; m2 <- q[[2]][k] - q[[3]][k]; r <- m1 / m2
  big <- abs(m2) / ev > 0.02
  for (role in c("resident", "invader")) {
    s <- startsWith(k, role) & big
    cat(sprintf("%s: move ratio median %.2f (IQR %.2f-%.2f), %d%% negative, n = %d; ln J ratio %.2f\n", role,
                median(r[s]), quantile(r[s], .25), quantile(r[s], .75), round(100 * mean(r[s] < 0)), sum(s),
                r[[paste(role, "ln J")]]))
  }
  est <- (q[[1]][k] - q[[2]][k]) / 3 / ev; err <- E[, 2]; b2 <- abs(err) > 0.1
  cat(sprintf("(L1, L2) estimate of L2's error: median |est|/|err| %.2f over %d quantities, covered %.2f, cor %.2f\n",
              median(abs(est[b2]) / abs(err[b2])), sum(b2), mean(abs(est[b2]) >= abs(err[b2])), cor(est, err)))
  est2 <- (q[[2]][k] - q[[3]][k]) / 3 / ev; err3 <- E[, 3]; b3 <- abs(err3) > 0.1
  if (any(b3)) cat(sprintf("(L2, L3) estimate of L3's error: median %.2f over %d, covered %.2f\n",
              median(abs(est2[b3]) / abs(err3[b3])), sum(b3), mean(abs(est2[b3]) >= abs(err3[b3]))))
}
cat("\n== move sizes in eps (median / max over quantities, recruitment_decay excluded)\n")
for (nm in names(lad)) {
  q <- lapply(lad[[nm]], function(k) quantities(rd(Q, paste0(k, "_episodic"))))
  k <- Reduce(intersect, c(lapply(q, names), list(names(ref)))); k <- k[!endsWith(k, nuisance)]; ev <- eps_vec(k)
  m1 <- abs(q[[1]][k] - q[[2]][k]) / ev; m2 <- abs(q[[2]][k] - q[[3]][k]) / ev
  cat(sprintf("%s: L1-L2 %.3f / %.3f; L2-L3 %.3f / %.3f\n", nm, median(m1), max(m1), median(m2), max(m2)))
}
