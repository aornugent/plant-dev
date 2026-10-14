# Where a committed run's accepted steps end and what they cost in rows: on a rain
# knot, on a node birth, at HMAX, or where the error controller chose.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/E/common.R")
classify <- function(x, kn) {
  t <- x$stand$times; h <- x$stand$sizes; nt <- sort(x$node_times); n <- length(t)
  end <- t[-1]; hh <- h[-1]; start <- t[-n]
  near <- function(a, b) { i <- findInterval(a, b); d1 <- abs(a - b[pmax(i, 1)]); d2 <- abs(a - b[pmin(i + 1, length(b))]); pmin(d1, d2) < 1e-9 }
  alive <- vapply(start, function(s) sum(nt <= s) + 1, 0)
  cls <- ifelse(near(end, nt), "birth", ifelse(near(end, kn), "knot", ifelse(hh > 0.999 * 15 / 365, "hmax", "ctrl")))
  # A step is "knot-bounded" if the controller would have stepped further: its size is
  # below the next step's. Here: count steps of each class and their rows.
  data.frame(start, end, h = hh, alive, cls)
}
res <- list()
for (cs in CASES10) for (cf in c("c", "f")) { x <- readRDS(a09_file(cs, cf)); s <- x$setting
  d <- classify(x, knots_of(s$regime, s$seed)); d$case <- cs; d$cf <- cf; res[[paste(cs, cf)]] <- d }
saveRDS(res, file.path(EO, "steps.rds"))
for (k in names(res)) { d <- res[[k]]; tb <- tapply(d$alive, d$cls, sum); nb <- table(d$cls)
  cat(sprintf("%-16s steps %5d rows %7.0f | steps birth %4d knot %4d hmax %4d ctrl %4d | rows%% birth %4.1f knot %4.1f hmax %4.1f ctrl %4.1f | median h ctrl %.2f d, knot %.2f d\n",
    k, nrow(d), sum(d$alive), nb["birth"], nb["knot"], nb["hmax"], nb["ctrl"], 100*tb["birth"]/sum(d$alive), 100*tb["knot"]/sum(d$alive), 100*tb["hmax"]/sum(d$alive), 100*tb["ctrl"]/sum(d$alive),
    365*median(d$h[d$cls=="ctrl"]), 365*median(d$h[d$cls=="knot"]))) }
