# The residue on the tight build (prereg.txt, fifth extension): second
# differences of ln J in ln lma for plain and the split on both builds, each
# against its own replay at r = 0, and the split's fine grid in r on both.
#   SC=... T=... Rscript tight_residue.R
SC <- Sys.getenv("SC"); T <- Sys.getenv("T")
lj <- function(f) log(readRDS(paste0(f, ".rds"))$stand$J)
H <- function(stem0, stem, u) {
  r <- as.numeric(u); hp <- log1p(r); hm <- -log1p(-r)
  2 * (lj(sprintf("%s_%s", stem, u)) / (hp * (hp + hm)) +
       lj(sprintf("%s_-%s", stem, u)) / (hm * (hp + hm)) - lj(stem0) / (hp * hm))
}
us <- c("1e-3", "3e-3", "1e-2", "3e-2")
arms <- list(
  "plain, split build" = c(file.path(SC, "runs", "plain_lma_0"), file.path(SC, "runs", "rp_lma")),
  "split, split build" = c(file.path(SC, "runs", "rs_lma_0"), file.path(SC, "runs", "rs_lma")),
  "plain, tight build" = c(file.path(T, "runs", "plain_lma_0"), file.path(T, "runs", "plain_lma")),
  "split, tight build" = c(file.path(T, "runs", "split_lma_0"), file.path(T, "runs", "split_lma")))
cat("Second differences at r = 1e-3, 3e-3, 1e-2, 3e-2, and 1e-3 less 1e-2:\n")
res <- c()
for (a in names(arms)) {
  h <- sapply(us, function(r) H(arms[[a]][1], arms[[a]][2], r))
  res[a] <- h[1] - h[3]
  cat(sprintf("  %-19s %s; %+.3f\n", a, paste(sprintf("%.3f", h), collapse = ", "), res[a]))
}

fine <- function(dir, k0) {
  k <- seq(0, 32, 2); r <- k * 1e-3 / 32
  y <- sapply(k, function(i) if (i == 0) lj(k0) else lj(file.path(dir, sprintf("fine_split_k%d", i))))
  mid <- (head(r, -1) + tail(r, -1)) / 2
  b <- median(diff(y) / diff(r) + 35.2 * mid)
  diff(y) - (b - 35.2 * mid) * diff(r)
}
ds <- fine(file.path(SC, "runs"), file.path(SC, "runs", "fine_split_k0"))
dt <- fine(file.path(T, "runs"), file.path(T, "runs", "split_lma_0"))
cat(sprintf("\nThe split's fine grid, 16 intervals of 6.25e-5: sd %.2e on the split build, %.2e on the tight\n",
            sd(ds), sd(dt)))
cat(sprintf("  tight: %s\n", paste(sprintf("%+.1e", dt), collapse = " ")))
cat(sprintf("  correlation between the builds %.2f\n", cor(ds, dt)))

r1 <- res[["split, tight build"]]
cat(sprintf("\nR1 (the split's residue on the tight build within +-0.1): %+.3f, %s\n", r1,
            if (abs(r1) <= 0.1) "holds" else if (r1 >= 0.4) "fails" else "neither"))
cat(sprintf("R2 (its fine grid's sd at most 1e-8): %.2e, %s\n", sd(dt),
            if (sd(dt) <= 1e-8) "holds" else if (sd(dt) >= 4e-8) "fails" else "neither"))
