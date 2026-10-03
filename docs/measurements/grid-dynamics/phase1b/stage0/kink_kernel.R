# The error of each pair's propagated solution for a unit slope jump of the
# rate at fraction u of the step, per h^2 (the driver's kink_kernel), and how
# far each stage's state reaches on a decaying mode y' = -y/T (the stage values
# at h/T = 1, 2, 3).
#   Rscript stage0/kink_kernel.R   (from phase1b/)
tab <- new.env(); sys.source("harness/ark436.R", envir = tab)
pairs <- with(tab, list(ck = list(A = ACK, b = bCK, c = cCK), dp = list(A = ADP, b = bDP, c = cDP)))
u <- seq(0, 1, by = 0.01)
for (m in names(pairs)) {
  tb <- pairs[[m]]
  K <- sapply(u, function(x) sum(tb$b * pmax(tb$c - x, 0)) - (1 - x)^2 / 2)
  cat(sprintf("%s: kink kernel max |K| %.4f at u = %.2f; mean |K| %.4f; rms %.4f\n", m, max(abs(K)), u[which.max(abs(K))],
              mean(abs(K)), sqrt(mean(K^2))))
  for (z in c(1, 2, 3)) {
    st <- solve(diag(6) + z * tb$A, rep(1, 6))
    cat(sprintf("   y' = -y/T at h/T = %g: stage values %s\n", z, paste(sprintf("%.3f", st), collapse = " ")))
  }
  cat(sprintf("   sum |a_ij| per row: %s\n", paste(sprintf("%.2f", rowSums(abs(tb$A))), collapse = " ")))
}
