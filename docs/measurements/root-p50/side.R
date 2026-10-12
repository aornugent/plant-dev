# Which side of each run's own root (rate = 0 boundary) H's nearest node falls, using the
# step that contains the root: a closing's last positive step, an opening's first.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs")
h <- readRDS(file.path(S, "rp50/H_dry.rds")); b1 <- 3.529
for (nm in c("0.02", "-0.02")) {
  cr <- as.data.frame(readRDS(file.path(Q, sprintf("rp_H_%s_dry.rds", nm)))$stand$creation)
  pos <- cr$rate > 0; k <- which(diff(pos) != 0)
  cl <- pos[k]                                   # TRUE: closing
  i <- ifelse(cl, k, k + 1)                      # the positive step holding the root
  s <- cr$start[i]; e <- cr$end[i]
  late <- s > b1
  j <- vapply(seq_along(i), function(q) { z <- if (cl[q]) e[q] else s[q]; which.min(abs(h - z)) }, 1L)
  n <- h[j]; tol <- 1e-9
  shut <- ifelse(cl, n >= e - tol, n <= s + tol); open <- ifelse(cl, n <= s + tol, n >= e - tol)
  near <- pmin(abs(n - s), abs(n - e)) * 365 < 2
  sel <- late & near
  cat(sprintf("root_P50 %s: late roots %d, with a node within 2 d of the root step %d: shut side %d (closings %d/%d, openings %d/%d), open side %d; root step length median %.2f d\n",
    nm, sum(late), sum(sel), sum(shut[sel]), sum(shut[sel] & cl[sel]), sum(sel & cl), sum(shut[sel] & !cl[sel]), sum(sel & !cl), sum(open[sel]), median((e - s)[late]) * 365))
}
