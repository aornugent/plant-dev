# Where the old premise's defect lives: the residual of 429's g against its
# linear interpolant through u108's (u215's) nodes, at the 429 nodes between them.
ADJ <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/perf/adjoint"
F <- read.csv(file.path(ADJ, "out", "nodes_uniform_429.csv"))
source(file.path(ADJ, "indicators.R"))
trap <- function(x, y) sum(0.5 * diff(x) * (y[-1] + y[-length(y)]))
for (step in c(4, 2)) {
  k <- seq(1, nrow(F), by = step)
  gi <- approx(F$b[k], F$g[k], xout = F$b)$y
  r <- F$g - gi                       # zero at the coarse nodes
  h <- F$b[2] - F$b[1]
  defect <- -h * r                    # trapezium over 429's nodes of (interp - g)
  tot <- trap(F$b[k], F$g[k]) - trap(F$b, F$g)
  o <- order(-abs(defect))
  share <- cumsum(defect[o]) / tot
  n10 <- which(share > 0.9)[1]
  cat(sprintf("u%d: premise defect %+.4f (sum of residual terms %+.4f); %d of %d in-between 429 nodes carry 90%%\n",
              length(k), tot, sum(defect), n10, sum(r != 0)))
  top <- head(o, 12)
  # second difference the coarse grid sees at the panel holding each top node
  j <- findInterval(F$b[top], F$b[k])
  dd <- vapply(j, function(i) { if (i < 2 || i >= length(k)) return(NA)
    (F$g[k][i - 1] - 2 * F$g[k][i] + F$g[k][i + 1]) / 8 }, 0)
  print(data.frame(b = F$b[top], g = F$g[top], f = F$f[top], interp = gi[top], residual = r[top],
                   defect = defect[top], coarse_second_diff_over_8 = dd), digits = 3, row.names = FALSE)
}
