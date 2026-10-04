# How rough ln J is in lma on a pinned grid, from runs already made: the
# bisections' neighbouring replays (bisect.log), the replays a change of 1e-12
# from lma (jumps.R), and the two arms' fine grids in r (jumps.R).
#   SC=... Rscript noise.R
# SC holds bisect_split_n1, bisect_split_n5 and near5 (bisect.sh's W) and runs
# (run.sh's R).
SC <- Sys.getenv("SC")
lj <- function(f) log(readRDS(f)$stand$J)

# The fine grids: each 6.25e-5 interval's change less the smooth change, whose
# slope is the arm's median at r = 0 and falls with r at the curvature, -35.2.
fine <- function(arm) {
  k <- seq(0, 32, 2); r <- k * 1e-3 / 32
  y <- sapply(k, function(i) lj(file.path(SC, "runs", sprintf("fine_%s_k%d.rds", arm, i))))
  mid <- (head(r, -1) + tail(r, -1)) / 2
  b <- median(diff(y) / diff(r) + 35.2 * mid)
  list(b = b, d = diff(y) - (b - 35.2 * mid) * diff(r))
}
s <- fine("split"); d <- fine("diff")

cat("Neighbouring replays at most 6.2e-8 apart in r, with no tracked change between\n")
cat("most of them: each change of ln J less the smooth change\n")
all <- NULL
for (w in c("bisect_split_n1", "bisect_split_n5", "near5")) {
  f <- list.files(file.path(SC, w), "^r_.*\\.rds$", full.names = TRUE)
  r <- as.numeric(sub("^r_(.*)\\.rds$", "\\1", basename(f)))
  y <- sapply(f, lj)
  o <- order(r); r <- r[o]; y <- y[o]
  dr <- diff(r); mid <- (head(r, -1) + tail(r, -1)) / 2
  dep <- (diff(y) - (s$b - 35.2 * mid) * dr)[dr <= 6.2e-8]
  cat(sprintf("  %-16s %2d intervals of %.1e to %.1e: rms %.2e, largest %.2e\n", w, length(dep),
              min(dr[dr <= 6.2e-8]), max(dr[dr <= 6.2e-8]), sqrt(mean(dep^2)), max(abs(dep))))
  all <- c(all, dep)
}
cat(sprintf("  pooled, %d intervals: rms %.2e, largest %.2e; a replay's own share %.2e\n",
            length(all), sqrt(mean(all^2)), max(abs(all)), sqrt(mean(all^2)) / sqrt(2)))

cat("\nA change of 1e-12 in lma, ln J less its replay at lma:\n")
for (a in c("plain", "rs", "diff")) {
  z <- lj(file.path(SC, "runs", sprintf("%s_lma_0.rds", a)))
  cat(sprintf("  %-5s %+.2e, %+.2e\n", a, lj(file.path(SC, "runs", sprintf("%s_lma_1e-12.rds", a))) - z,
              lj(file.path(SC, "runs", sprintf("%s_lma_-1e-12.rds", a))) - z))
}

keep <- abs(d$d) < 3e-7
cat("\nThe fine grids, 16 intervals of 6.25e-5 between r = 0 and 1e-3:\n")
cat(sprintf("  split: sd %.2e; corrected: sd %.2e without its one jump of %.2e\n",
            sd(s$d), sd(d$d[keep]), d$d[!keep]))
cat(sprintf("  the arms' correlation over the other 15: %.2f, signs agreeing in %d; their\n",
            cor(s$d[keep], d$d[keep]), sum(sign(s$d[keep]) == sign(d$d[keep]))))
cat(sprintf("  difference's sd %.2e, against %.2e for four replays' own shares\n",
            sd(s$d[keep] - d$d[keep]), sqrt(2) * sqrt(mean(all^2))))
cat(sprintf("  slope at r = 0 (d ln J / dr): split %.4f, corrected %.4f\n", s$b, d$b))

# Second differences of ln J in ln lma against each arm's replay at r = 0, as
# jumps.R takes them, and what the corrected arm's one jump inside +1e-3 adds.
H <- function(a, r) {
  up <- lj(file.path(SC, "runs", sprintf("%s_lma_%s.rds", a, r)))
  dn <- lj(file.path(SC, "runs", sprintf("%s_lma_-%s.rds", a, r)))
  z <- lj(file.path(SC, "runs", sprintf("%s_lma_0.rds", a)))
  r <- as.numeric(r); hp <- log1p(r); hm <- -log1p(-r)
  2 * (up / (hp * (hp + hm)) + dn / (hm * (hp + hm)) - z / (hp * hm))
}
cat("\nSecond differences at r = 1e-3 less at 1e-2:\n")
for (a in c("rs", "diff", "fix")) cat(sprintf("  %-4s %+.3f\n", a, H(a, "1e-3") - H(a, "1e-2")))
cat(sprintf("  the corrected arm's jump moves its value at 1e-3 by %+.3f\n",
            2 * d$d[!keep] / (log1p(1e-3) * (log1p(1e-3) - log1p(-1e-3)))))
