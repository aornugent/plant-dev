# The noise's source (prereg.txt, fourth extension): ln J on the plain program
# at lma (1 + k 1e-12), k = -3..3, on the split build and on the tight build, and
# each change between neighbouring k less the smooth change, -8.277e-12 a step.
#   SC=... T=... Rscript tight.R
SC <- Sys.getenv("SC"); T <- Sys.getenv("T")
k <- -3:3
tag <- function(i) if (i == 0) "0" else sprintf("%de-12", i)
secs <- function(dir, i) {
  l <- readLines(file.path(dir, sprintf("plain_lma_%s.log", tag(i))))
  as.numeric(sub(".*; ([0-9.]+) s$", "\\1", grep(" s$", l, value = TRUE)[1]))
}
rms <- c()
for (b in list(c("split build", file.path(SC, "runs")), c("tight build", file.path(T, "runs")))) {
  y <- sapply(k, function(i) log(readRDS(file.path(b[2], sprintf("plain_lma_%s.rds", tag(i))))$stand$J))
  d <- diff(y) + 8.277e-12
  rms[b[1]] <- sqrt(mean(d^2))
  cat(sprintf("%s: ln J at k = 0 %.12f\n  neighbouring changes less the smooth one: %s\n  rms %.2e\n",
              b[1], y[4], paste(sprintf("%+.1e", d), collapse = " "), rms[b[1]]))
  if (b[1] == "tight build") {
    t <- sapply(k, function(i) secs(b[2], i))
    cat(sprintf("  seconds a replay: %s\n", paste(round(t), collapse = " ")))
  }
}
ratio <- rms[["tight build"]] / rms[["split build"]]
cat(sprintf("\ntight over split: %.3g; T1 (at most 0.1) %s, fails at 0.5 or more\n", ratio,
            if (ratio <= 0.1) "holds" else if (ratio >= 0.5) "fails" else "partly"))
