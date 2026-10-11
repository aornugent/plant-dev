# The steep-fate check: the largest change between neighbouring nodes (both with
# count) in log net reproduction and in survival to the run's end, exp(-m).
src <- readLines("../placement/score.R"); eval(parse(text = src[1:grep("^fmt <-", src)]))
Q <- file.path(D, "schedtest", "placed2", "runs")
get <- function(nm) { for (d in c(Q, NR, PF, P)) { o <- rd(d, nm); if (!is.null(o)) return(o) }; NULL }
for (nm in commandArgs(TRUE)) {
  o <- get(nm); if (is.null(o)) next; n <- o$stand$nodes; k <- length(n$birth)
  cnt <- n$establishment[1:k]; ok <- cnt[-k] > 1e-3 * max(cnt) & cnt[-1] > 1e-3 * max(cnt)
  dl <- abs(diff(log(pmax(n$nrr, 1e-12))))[ok]; ds <- abs(diff(exp(-n$mortality)))[ok]
  cat(sprintf("%-26s %4d nodes | max |dlog nrr| %.2f (99%% %.2f) | max |d survival| %.3f (99%% %.3f)\n", nm, k,
      max(dl), quantile(dl, .99), max(ds), quantile(ds, .99)))
}
