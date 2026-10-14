# Per-recruit fate (nrr) at each edge, 10 d inside its spell (in10) and 10 d inside its gap
# (out10), against the hat interpolant the base uses there.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
a <- commandArgs(TRUE); cs <- a[1]
nod <- function(x) data.frame(b = x$stand$nodes$birth, nrr = x$stand$nodes$nrr)
B <- nod(rd_run("a09", "c", cs)); I <- nod(readRDS(file.path(POUT, "runs", sprintf("P_in10_%s.rds", cs)))); O <- nod(readRDS(file.path(POUT, "runs", sprintf("P_out10_%s.rds", cs))))
et <- edge_table(cs); et <- et[et$gap > 22 & et$spell > 22, ]   # edges whose shifts are the full 10 d
f <- function(D, b) approx(D$b, log(D$nrr), b)$y
r <- data.frame(b = round(et$b, 3), open = et$opening, gap = round(et$gap), spell = round(et$spell),
  edge = f(B, et$b), inside = f(I, et$b + ifelse(et$opening, 10, -10) / 365), gapside = f(O, et$b + ifelse(et$opening, -10, 10) / 365),
  base_hat_inside = f(B, et$b + ifelse(et$opening, 10, -10) / 365))
r$d_edge_inside <- r$edge - r$inside; r$d_hat <- r$base_hat_inside - r$inside; r$d_gapside <- r$gapside - r$edge
print(format(r, digits = 3), row.names = FALSE)
for (o in c(TRUE, FALSE)) { z <- r[r$open == o, ]; cat(sprintf("%s edges (n %d): ln nrr edge - 10 d inside: med %+.3f, mean |.| %.3f | base hat at 10 d inside - truth: med %+.3f mean|.| %.3f | 10 d into gap - edge: med %+.3f mean|.| %.3f\n",
  if (o) "opening" else "closing", nrow(z), median(z$d_edge_inside), mean(abs(z$d_edge_inside)), median(z$d_hat), mean(abs(z$d_hat)), median(z$d_gapside), mean(abs(z$d_gapside)))) }
