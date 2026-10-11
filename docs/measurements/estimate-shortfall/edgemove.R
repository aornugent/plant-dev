# Do the edges move as the grid is refined? Edges of the first pass (u54) against
# edges of a forward run on pass 3's grid, and the distance from each pass-3 edge
# to the nearest node of that grid.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
edges <- function(cr) { op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths)
  data.frame(b = cr$end[e][-length(e)], opening = !op[e][-length(e)]) }
e1 <- edges(readRDS(file.path(S, "placed2/runs/m_th0_f_episodic.rds"))$stand$creation)
x3 <- readRDS(file.path(S, "placed2/runs/fwd_u108e_p3_episodic.rds")); e3 <- edges(x3$stand$creation)
t3 <- readRDS(file.path(S, "refine/ref_u108e_episodic_p3_times.rds"))
e1 <- e1[e1$b > 0 & e1$b < 40, ]; e3 <- e3[e3$b > 0 & e3$b < 40, ]
near <- function(v, ref) vapply(v, function(z) min(abs(ref - z)), 0)
cat(sprintf("edges: first pass %d, pass-3 run %d\n", nrow(e1), nrow(e3)))
for (op in c(TRUE, FALSE)) { a <- e3[e3$opening == op, ]; d1 <- near(a$b, e1$b[e1$opening == op]) * 365; dn <- near(a$b, t3) * 365
  cat(sprintf("%s: pass-3 edge to nearest first-pass edge (days): median %.3f, >1 d %d of %d, >7 d %d | to nearest node: median %.3f, >1 d %d\n",
    if (op) "openings" else "closings", median(d1), sum(d1 > 1), nrow(a), sum(d1 > 7), median(dn), sum(dn > 1))) }
a <- e3; a$dnode <- near(a$b, t3) * 365; print(head(a[order(-a$dnode), ], 12), row.names = FALSE)
