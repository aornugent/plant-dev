# The split finished in the forward step (prereg.txt, ninth extension).
#   OUTD=... PLANT_LIB=... Rscript final.R
OUTD <- Sys.getenv("OUTD")
# Each node's share of J: its establishment weight times its net reproduction
# ratio times the density of patches of its age at its birth (node_parts.R).
if (nzchar(Sys.getenv("PLANT_LIB"))) .libPaths(c(Sys.getenv("PLANT_LIB"), .libPaths()))
share_of <- function(x) {
  n <- x$stand$nodes
  m <- min(length(n$establishment), length(n$nrr))
  pd <- plant::Weibull_Disturbance_Regime(x$setting$lifetime)
  w <- n$establishment[1:m] * n$nrr[1:m] * vapply(n$birth[1:m], pd$density, 0)
  w / sum(w)
}
rd <- function(f) readRDS(file.path(OUTD, paste0(f, ".rds")))
secs <- function(f) {
  l <- grep(" s$", readLines(file.path(OUTD, paste0(f, ".log"))), value = TRUE)[1]
  as.numeric(sub(".*; ([0-9.]+) s$", "\\1", l))
}
scan <- function(r) {
  x <- readLines(file.path(OUTD, sprintf("scan_%s.txt", r)))
  s <- read.table(text = grep("^scan ", x, value = TRUE), col.names = c(
    "tag", "t", "h", "p", "cuts", "changes", "u_first", "u_last", "v0", "v1", "other"))
  sp <- read.table(text = grep("^split ", x, value = TRUE), col.names = c(
    "tag", "t", "h", "p", "n", "u1", "u2", "v0", "v1", "inside"))
  list(scan = s, split = sp)
}
for (r in c("0", "-1e-3")) {
  sc <- tryCatch(scan(r), error = function(e) NULL)
  if (is.null(sc)) { cat(sprintf("r = %s: no scan disagreements logged\n", r)); next }
  m <- sc$scan[sc$scan$changes > sc$scan$cuts, ]
  cat(sprintf("r = %s: %d node steps split, %d whose scan disagrees, %d with more changes than cuts\n",
              r, nrow(sc$split), nrow(sc$scan), nrow(m)))
  if (nrow(m)) print(transform(m[, c("t", "h", "p", "cuts", "changes", "u_first", "u_last", "v0", "v1", "other")],
                               t = round(t * 365, 2), h = round(h * 365, 3)))
  n5 <- sc$split[sc$split$p == 4 & abs(sc$split$t - 8684 / 365) < 1e-6, ]
  cat(sprintf("  node 5 on day 8684: %s\n", if (nrow(n5)) sprintf("%d cut(s) at u = %s", n5$n[1],
      paste(signif(c(n5$u1[1], if (n5$n[1] > 1) n5$u2[1]), 4), collapse = ", ")) else "not split"))
}
cat(sprintf("S1 (no pair missed at r = 0): %s\n", {
  sc <- tryCatch(scan("0"), error = function(e) NULL)
  k <- if (is.null(sc)) 0 else sum(sc$scan$changes > sc$scan$cuts)
  if (k == 0) "holds" else if (k >= 3) sprintf("fails (%d)", k) else sprintf("neither (%d)", k)
}))
if (!file.exists(file.path(OUTD, "split_2.rds"))) {
  cat("the timed runs and the record: not run here\n")
  quit(save = "no")
}
p <- sapply(1:2, function(i) secs(sprintf("plain_%d", i)))
s <- sapply(1:2, function(i) secs(sprintf("split_%d", i)))
extra <- mean(s) / mean(p) - 1
cat(sprintf("plain's replay %s s, the split's %s s: the split's extra %.1f%%\n",
            paste(p, collapse = ", "), paste(s, collapse = ", "), 100 * extra))
cat(sprintf("S2 (at most 4%%): %s\n", if (extra <= 0.04) "holds" else if (extra >= 0.06) "fails" else "neither"))
f <- rd("split_1")
rec <- f$stand$split_record
cat(sprintf("S3 (the record adds up): sum %d against ode_splits %d: %s\n", sum(rec$split), f$stand$splits,
            if (sum(rec$split) == f$stand$splits) "holds" else "fails"))
share <- share_of(f)
stopifnot(length(share) == length(rec$split))
cat(sprintf("nodes split %d of %d, carrying %.3f of J; searched %d nodes (%d node steps), carrying %.3f of J\n",
            sum(rec$split > 0), length(rec$split), sum(share[rec$split > 0]),
            sum(rec$searched > 0), sum(rec$searched), sum(share[rec$searched > 0])))
cat(sprintf("unsplit: node(s) %s, carrying %.2g of J; splits a node: median %g, at most %d; searched at most %d on one node\n",
            paste(which(rec$split == 0), collapse = " "), sum(share[rec$split == 0]),
            median(rec$split), max(rec$split), max(rec$searched)))
cat(sprintf("never searched: %d nodes, carrying %.2g of J; the split's extra time a node step split: %.3f ms\n",
            sum(rec$searched == 0), sum(share[rec$searched == 0]), 1000 * (mean(s) - mean(p)) / f$stand$splits))
cat(sprintf("the slowest crossing: |dP/dt| %.3g at day %.2f, node %d\n",
            rec$least_rate, rec$least_rate_time * 365, rec$least_rate_node))
cat(sprintf("  that node carries %.2g of J\n", share[rec$least_rate_node]))
ns <- rd("nosearch_0")
cat(sprintf("ln J at r = 0: final %.12f, without the search %.12f, difference %+.3e; node steps split %d against %d\n",
            log(f$stand$J), log(ns$stand$J), log(f$stand$J) - log(ns$stand$J), f$stand$splits, ns$stand$splits))
