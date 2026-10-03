# Where each stage of CK and DP first goes negative on a decaying mode
# y' = -y/T (ark436.R's question for the pools), and where the step does.
#   Rscript stage0/first_negative.R   (from phase1b/)
tab <- new.env(); sys.source("harness/ark436.R", envir = tab)
x <- seq(0, 6, by = 1e-4)
for (m in c("CK", "DP")) {
  A <- if (m == "CK") tab$ACK else tab$ADP
  b <- if (m == "CK") tab$bCK else tab$bDP
  v <- sapply(-x, function(z) solve(diag(6) - z * A, rep(1, 6)))
  fn <- apply(v, 1, function(row) { k <- which(row < 0)[1]; if (is.na(k)) NA else x[k] })
  stp <- sapply(-x, function(z) 1 + z * sum(b * solve(diag(6) - z * A, rep(1, 6))))
  cat(sprintf("%s: first negative stage value at h/T, stages 1..6: %s; the step's value first negative at %.4f\n", m,
              paste(format(fn, digits = 4), collapse = " "), x[which(stp < 0)[1]]))
}
