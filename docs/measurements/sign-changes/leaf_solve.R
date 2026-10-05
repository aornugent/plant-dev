# The leaf solve stopped at adjacent floats, as built (prereg.txt, eighth
# extension): the replay noise on the build, its ln J against the tight build's,
# and plain's replay timed alone.
#   OUTD=... Rscript leaf_solve.R
OUTD <- Sys.getenv("OUTD")
lj <- function(f) log(readRDS(paste0(f, ".rds"))$stand$J)
secs <- function(f) {
  l <- grep(" s$", readLines(paste0(f, ".log")), value = TRUE)[1]
  as.numeric(sub(".*; ([0-9.]+) s$", "\\1", l))
}
k <- -3:3
u <- c("-3e-12", "-2e-12", "-1e-12", "0", "1e-12", "2e-12", "3e-12")
y <- sapply(u, function(s) lj(file.path(OUTD, paste0("plain_lma_", s))))
d <- diff(y) - mean(diff(y))
cat(sprintf("new build: ln J at k = 0 %.12f\n  neighbouring changes less the smooth one: %s\n  rms %.2e\n",
            y[4], paste(sprintf("%+.1e", d), collapse = " "), sqrt(mean(d^2))))
cat(sprintf("T2 (rms at most 1e-13): %s\n", if (sqrt(mean(d^2)) <= 1e-13) "holds" else if (sqrt(mean(d^2)) >= 1e-10) "fails" else "neither"))
dt <- y[4] - 2.539169356461
cat(sprintf("T3 (within 1e-9 of the tight build's 2.539169356461): %+.2e, %s\n", dt,
            if (abs(dt) <= 1e-9) "holds" else if (abs(dt) > 1e-7) "fails" else "neither"))
cat(sprintf("against the split build's 2.539170868131: %+.3e\n", y[4] - 2.539170868131))
s <- sapply(1:2, function(i) secs(file.path(OUTD, sprintf("time_split_%d", i))))
n <- sapply(1:2, function(i) secs(file.path(OUTD, sprintf("time_new_%d", i))))
cat(sprintf("plain's replay alone: split build %s s, new build %s s; new over split %.3f\n",
            paste(s, collapse = ", "), paste(n, collapse = ", "), mean(n) / mean(s)))
