.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
# Where L0's move sits: per region of birth date, the moves L0->L1 and L1->L2 in ln J
# (field + establishment + interpolation, panel_moves), and their ratio.
source("/home/user/plant-dev/harness/node_parts.R")
Q <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/placed2/runs"
for (cs in list(c("th0","episodic"), c("th0","dry"), c("th0","long-wet"), c("lma125","episodic"), c("lma125","long-wet"))) {
  tag <- cs[1]; rec <- cs[2]
  r <- lapply(c("", "2", "4"), function(L) readRDS(file.path(Q, sprintf("m_%s%s_%s.rds", tag, L, rec))))
  f <- readRDS(file.path(Q, sprintf("m_%s_f_%s.rds", tag, rec)))$stand$creation
  op <- f$rate > 0.01; rl <- rle(op); e <- cumsum(rl$lengths); ed <- f$end[e][-length(e)]; kind <- !op[e][-length(e)]  # TRUE = opening
  first_close <- ed[!kind][1]
  n <- lapply(r, nodes_of)
  mv <- function(a, b) { pm <- panel_moves(a, b); J <- sum(a$w * a$offspring)
    data.frame(birth = a$birth, m = (pm$field + pm$establishment + pm$interpolation) / J) }
  m1 <- mv(n[[1]], n[[2]]); m2 <- mv(n[[2]], n[[3]])
  # regions: founders' window [0, first closing); first-mover layer = first 0.5 d after each later opening; rest by band
  reg <- function(b) { o <- ed[kind]; lo <- o[findInterval(b, o)]; ifelse(b < first_close, ifelse(b < 0.5, "found <0.5", "found rest"),
      ifelse(!is.na(lo) & b - lo < 0.5 & b >= lo, "layer 0.5d", ifelse(b < 3, "other <3", ifelse(b < 10, "other 3-10", "other >10")))) }
  t1 <- tapply(m1$m, reg(m1$birth), sum); t2 <- tapply(m2$m, reg(m2$birth), sum)
  k <- union(names(t1), names(t2)); t1 <- t1[k]; t2 <- t2[k]; t1[is.na(t1)] <- 0; t2[is.na(t2)] <- 0
  cat(sprintf("\n== %s %s: first closing %.3f, J moves %+.5f / %+.5f (ratio %.2f)\n", tag, rec, first_close, sum(m1$m), sum(m2$m), sum(m1$m)/sum(m2$m)))
  for (i in seq_along(k)) cat(sprintf("  %-11s L0->L1 %+.5f  L1->L2 %+.5f  ratio %6.2f | abs %.5f %.5f\n", k[i], t1[i], t2[i], t1[i]/t2[i],
     sum(abs(m1$m[reg(m1$birth)==k[i]])), sum(abs(m2$m[reg(m2$birth)==k[i]]))))
}
