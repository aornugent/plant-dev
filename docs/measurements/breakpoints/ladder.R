# Score nested ladders on one record: errors against the reference, rows, move
# ratios, and the pair's estimate.  Rscript ladder.R RECORD L1,L2[,L3] [L1,L2,L3 ...]
src <- readLines("../placement/score.R"); eval(parse(text = src[1:grep("^fmt <-", src)]))
Q <- file.path(D, "schedtest", "placed2", "runs")
args <- commandArgs(TRUE); rec <- args[1]
refs$dry <- list(m = rd(NR, "u215_dry"), f = rd(NR, "u429_dry"), name = "u215+u429 (nr)")
refs$`long-wet` <- list(m = rd(NR, "u215_long-wet"), f = rd(NR, "u429_long-wet"), name = "u215+u429 (nr)")
ref <- { rf <- refs[[rec]]; qm <- quantities(rf$m); qf <- quantities(rf$f); k <- intersect(names(qm), names(qf)); extrap(qm[k], qf[k]) }
get <- function(nm) { o <- rd(Q, nm); if (is.null(o)) o <- rd(NR, nm); if (is.null(o)) o <- rd(PF, nm); if (is.null(o)) o <- rd(P, nm); o }
cat(sprintf("== %s (reference %s); errors in eps, recruitment_decay excluded\n", rec, refs[[rec]]$name))
for (spec in args[-1]) {
  nm <- strsplit(spec, ",")[[1]]; o <- lapply(nm, get)
  if (any(sapply(o, is.null))) { cat(spec, ": missing\n"); next }
  q <- lapply(o, quantities); k <- Reduce(intersect, c(lapply(q, names), list(names(ref)))); k <- k[!endsWith(k, nuisance)]
  ev <- eps_vec(k); E <- sapply(q, function(v) (v[k] - ref[k]) / ev)
  cat(sprintf("\n%s\n  nodes %s; rows %s\n  max |err| %s; median |err| %s; > eps %s\n", spec,
      paste(sapply(o, function(x) length(x$stand$nodes$birth)), collapse = "/"),
      paste(sapply(o, function(x) sprintf("%.0fk", rows_of(x) / 1e3)), collapse = "/"),
      paste(sprintf("%.2f", apply(abs(E), 2, max)), collapse = "/"), paste(sprintf("%.3f", apply(abs(E), 2, median)), collapse = "/"),
      paste(colSums(abs(E) > 1), collapse = "/")))
  est <- (q[[1]][k] - q[[2]][k]) / 3 / ev; e2 <- E[, 2]; b <- abs(e2) > 0.1
  if (any(b)) cat(sprintf("  (L1-L2)/3 against L2's error: median %.2f over %d, covered %.0f%%, cor %.2f\n",
      median(abs(est[b]) / abs(e2[b])), sum(b), 100 * mean(abs(est[b]) >= abs(e2[b])), cor(est, e2)))
  if (length(q) >= 3) {
    m1 <- q[[1]][k] - q[[2]][k]; m2 <- q[[2]][k] - q[[3]][k]; r <- m1 / m2; big <- abs(m2) / ev > 0.01
    for (role in c("resident", "invader")) { s <- startsWith(k, role) & big
      if (any(s)) cat(sprintf("  %s move ratio median %.2f (IQR %.2f-%.2f), %d%% negative, n = %d\n", role, median(r[s]),
          quantile(r[s], .25), quantile(r[s], .75), round(100 * mean(r[s] < 0)), sum(s))) }
    cat(sprintf("  ln J move ratio %.2f; (L1-L2)/3 over L2-L3: median %.2f (honest 1.33)\n", r[["resident ln J"]],
        median((m1[big] / 3) / m2[big])))
  }
}
