# Where the a_l1 elasticity's move between nested constant grids sits: central
# differences (a_l1 x(1 +- 0.02)) of each panel's part of J's move, by birth day.
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
source("/home/user/plant-dev/harness/node_parts.R")
Q <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/placed2/runs"
r <- function(n) readRDS(file.path(Q, paste0("el_", n, "_constant.rds"))); u <- 0.02
br <- c(0, 7, 14, 20, 22, 23, 23.4, 23.5, 23.6, 24, 26, 30, 60, 365, 365 * 41) / 365
for (pr in list(c("baseF", "baseF2"), c("cF", "cF2"))) {
  part <- function(s) { a <- nodes_of(r(paste0(pr[1], "_", s))); b <- nodes_of(r(paste0(pr[2], "_", s))); pm <- panel_moves(a, b)
    list(birth = a$birth, m = (pm$field + pm$establishment + pm$interpolation) / sum(a$w * a$offspring)) }
  p <- part("p"); m <- part("m"); d <- (p$m - m$m) / (2 * u)
  el <- function(n) { x <- c(r(paste0(n, "_p"))$stand$J, r(paste0(n, "_m"))$stand$J); diff(rev(log(x))) / (2 * u) }
  cat(sprintf("\n== %s -> %s: FD elasticity %.4f -> %.4f (move %+.4f), sum of panel parts %+.4f\n", pr[1], pr[2], el(pr[1]), el(pr[2]), el(pr[2]) - el(pr[1]), sum(d)))
  t <- tapply(d, cut(p$birth, br, right = FALSE, labels = sprintf("%g-%g d", head(br * 365, -1), br[-1] * 365)), sum)
  print(round(t[!is.na(t)], 4))
}
