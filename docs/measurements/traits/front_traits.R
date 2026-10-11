# The constant front per trait setting: first birth after day 10 whose
# sign-change count exceeds that of the births just before it, and the rise in
# end mortality over the next 0.25 day.
Q <- "../placed2/runs"
for (k in c("base", "lma08", "lma125", "hmat08", "hmat125", "dG1h", "dG1d", "st1h", "st1d")) {
  f <- file.path(Q, paste0("t_", k, ".rds")); if (!file.exists(f)) { cat(k, "missing\n"); next }
  x <- readRDS(f)$stand; d <- 365 * x$nodes$birth; s <- x$splits; m <- x$nodes$mortality
  i <- which(d > 10 & d < 45); j <- i[which(s[i] > s[i[1]])[1]]
  b <- d[j]; up <- approx(d, m, b + 0.25)$y - m[j - 1]
  cat(sprintf("%-8s J %9.3f | front at day %7.3f (previous node %7.3f; counts %d -> %d) | end-mortality rise over 0.25 d %7.2f\n",
      k, x$J, b, d[j - 1], s[j - 1], s[j], up))
}
