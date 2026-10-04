# The splits reply's two cheap checks (prereg.txt, sixth extension): the tight
# leaf solve's cost timed alone, and the split's fine grid and second
# differences with the positive part's width at 1e-3 against 1e-4, both on the
# tight build.
#   SC=... T=... Rscript band.R
SC <- Sys.getenv("SC"); T <- Sys.getenv("T")
lj <- function(f) log(readRDS(paste0(f, ".rds"))$stand$J)
secs <- function(f) {
  l <- grep(" s$", readLines(paste0(f, ".log")), value = TRUE)[1]
  as.numeric(sub(".*; ([0-9.]+) s$", "\\1", l))
}
d <- sapply(1:2, function(i) secs(file.path(T, "timing", sprintf("default_%d", i))))
t <- sapply(1:2, function(i) secs(file.path(T, "timing", sprintf("tight_%d", i))))
cat(sprintf("plain's replay alone: split build %s s, tight build %s s; tight over split %.3f\n",
            paste(d, collapse = ", "), paste(t, collapse = ", "), mean(t) / mean(d)))

fine <- function(dir, k0) {
  k <- seq(0, 32, 2); r <- k * 1e-3 / 32
  y <- sapply(k, function(i) if (i == 0) lj(k0) else lj(file.path(dir, sprintf("fine_split_k%d", i))))
  mid <- (head(r, -1) + tail(r, -1)) / 2
  b <- median(diff(y) / diff(r) + 35.2 * mid)
  diff(y) - (b - 35.2 * mid) * diff(r)
}
H <- function(stem0, stem, u) {
  r <- as.numeric(u); hp <- log1p(r); hm <- -log1p(-r)
  2 * (lj(sprintf("%s_%s", stem, u)) / (hp * (hp + hm)) +
       lj(sprintf("%s_-%s", stem, u)) / (hm * (hp + hm)) - lj(stem0) / (hp * hm))
}
for (b in list(c("width 1e-4", file.path(T, "runs")), c("width 1e-3", file.path(T, "runs_eps")))) {
  dep <- fine(b[2], file.path(b[2], "split_lma_0"))
  h <- sapply(c("1e-3", "1e-2"), function(u) H(file.path(b[2], "split_lma_0"), file.path(b[2], "split_lma"), u))
  cat(sprintf("\n%s: ln J at r = 0 %.10f\n  fine grid sd %.2e: %s\n  second differences %.3f, %.3f; 1e-3 less 1e-2 %+.3f\n",
              b[1], lj(file.path(b[2], "split_lma_0")), sd(dep), paste(sprintf("%+.1e", dep), collapse = " "),
              h[1], h[2], h[1] - h[2]))
  assign(gsub("[^a-z0-9]", "_", b[1]), sd(dep))
}
ratio <- width_1e_3 / width_1e_4
cat(sprintf("\nB1 (the band carries the slower departure): sd ratio %.2f; holds at 3 or more, fails at 1.5 or less: %s\n",
            ratio, if (ratio >= 3) "holds" else if (ratio <= 1.5) "fails" else "neither"))
