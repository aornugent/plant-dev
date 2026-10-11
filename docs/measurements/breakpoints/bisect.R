# Measure 2. make: from map run MAP, the schedules bisecting both of P's
# intervals in K panels chosen by |own + field| (map), |own| alone (own), or at
# random (seed 1). score: each bisected run's move in ln J against -sum(D_hat)/4.
#   Rscript bisect.R make MAP K   |   Rscript bisect.R score MAP K
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
args <- commandArgs(TRUE)
x <- run(args[2]); k <- as.integer(args[3])
b <- nd(x); Jn <- sum(b$w * b$offspring)
own <- own_drop(b, x$dropped) / Jn
field <- colSums(x$light + x$soil) / x$stand$J
set.seed(1)
pick <- list(map = order(-abs(own + field))[1:k], own = order(-abs(own))[1:k],
             random = sort(sample(length(own), k)))
t <- x$node_times
for (m in names(pick)) {
  j <- x$dropped[pick[[m]]]
  f <- file.path(A, "sched", sprintf("bis_%s_%s.rds", args[2], m))
  if (args[1] == "make") {
    saveRDS(sort(c(t, (t[j - 1] + t[j]) / 2, (t[j] + t[j + 1]) / 2)), f)
    next
  }
  y <- run(sprintf("bis_%s_%s", args[2], m))
  if (is.null(y$stand$J)) next
  pred <- -sum(own[pick[[m]]] + field[pick[[m]]]) / 4
  meas <- log(y$stand$J) - log(x$stand$J)
  cat(sprintf("%-14s %-6s %2d panels: ln J moves %s, predicted %s (own %s, field %s), x%.2f; rows %+.1f%%\n",
              args[2], m, k, fmt(meas, 6), fmt(pred, 6), fmt(-sum(own[pick[[m]]]) / 4, 6),
              fmt(-sum(field[pick[[m]]]) / 4, 6), meas / pred, 100 * (y$stand$rows / x$stand$rows - 1)))
}
if (args[1] == "make") cat("panels (map):", sort(pick$map), "\nbirths:", round(b$birth[x$dropped[sort(pick$map)]], 2), "\n")
