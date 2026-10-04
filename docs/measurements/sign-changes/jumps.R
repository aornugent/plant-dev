# What a second difference at r = 1e-3 reads on a pinned grid (prereg.txt's
# third extension and what followed it): the curvature against each arm's own
# replay at r = 0, how far ln J moves for a change of 1e-12 in lma, and ln J at
# r = k/32 1e-3 against a smooth curve.
#   R=... Rscript jumps.R
R <- Sys.getenv("R")
J <- function(tag) {
  f <- file.path(R, paste0(tag, ".rds"))
  if (file.exists(f)) readRDS(f)$stand$J else NA_real_
}
H_of <- function(Jp, Jm, J0, r) {
  hp <- log1p(r); hm <- -log1p(-r)
  2 * (log(Jp) / (hp * (hp + hm)) + log(Jm) / (hm * (hp + hm)) - log(J0) / (hp * hm))
}

cat("H(r) against each arm's replay at r = 0 (its forward in parentheses):\n")
arms <- list(split = c("rs", "split_1e-4"), "split, corrected" = c("diff", "diff_1e-4"),
             "corrected, scanned" = c("fix", "fix_1e-4"))
for (a in names(arms)) {
  p <- arms[[a]][1]
  h <- sapply(c("1e-3", "1e-2", "3e-2"), function(r) {
    up <- J(sprintf("%s_lma_%s", p, r)); dn <- J(sprintf("%s_lma_-%s", p, r))
    c(H_of(up, dn, J(sprintf("%s_lma_0", p)), as.numeric(r)), H_of(up, dn, J(arms[[a]][2]), as.numeric(r)))
  })
  cat(sprintf("  %-19s %s; 1e-3 less 1e-2 %+.2f eps\n", a,
              paste(sprintf("%.3f (%.3f)", h[1, ], h[2, ]), collapse = ", "), (h[1, 1] - h[1, 2]) / 1.168))
}

cat("\nln J for a change of 1e-12 in lma, less ln J at r = 0 (the smooth change is 8.3e-12):\n")
for (p in c("plain", "rs", "diff")) {
  b <- J(sprintf("%s_lma_0", p))
  cat(sprintf("  %-5s +1e-12 %+.2e, -1e-12 %+.2e%s\n", p, log(J(sprintf("%s_lma_1e-12", p)) / b),
              log(J(sprintf("%s_lma_-1e-12", p)) / b),
              if (is.finite(J(sprintf("%s_lma_1e-300", p))))
                sprintf("; LMA_REL = 1e-300, lma as it is: %+.2e", log(J(sprintf("%s_lma_1e-300", p)) / b)) else ""))
}

# Each interval's change in ln J less the smooth change, whose slope is the
# intervals' median at r = 0 and falls with r at the curvature, -35.2.
cat("\nln J at r = k/32 1e-3, k even: each interval's departure from the smooth change\n")
for (arm in c("split", "diff")) {
  k <- seq(0, 32, 2); r <- k * 1e-3 / 32
  lj <- log(sapply(k, function(i) J(sprintf("fine_%s_k%d", arm, i))))
  if (any(!is.finite(lj))) next
  mid <- (head(r, -1) + tail(r, -1)) / 2
  b <- median(diff(lj) / diff(r) + 35.2 * mid)
  d <- diff(lj) - (b - 35.2 * mid) * diff(r)
  cat(sprintf("  %-5s %s\n", arm, paste(sprintf("%+.1e", d), collapse = " ")))
  cat(sprintf("        largest %+.2e between r = %.3e and %.3e; sd %.1e\n", d[which.max(abs(d))],
              r[which.max(abs(d))], r[which.max(abs(d)) + 1], sd(d)))
}
