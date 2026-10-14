# layer.R CASE BASE IN10 OUT10: P's layer.R on any three runs (names as in AG_out/runs,
# P_out/runs or adjmap/runs): per-recruit fate ln nrr at each g-edge (lib19 pilot), 10 d
# inside its spell and 10 d into its gap, against the base's hat interpolant there.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
a <- commandArgs(TRUE); cs <- a[1]
rdx <- function(nm) { for (d in c(AGR, file.path(POUT, "runs"), R)) { f <- file.path(d, paste0(nm, ".rds")); if (file.exists(f)) return(readRDS(f)) }; stop(nm) }
nod <- function(x) data.frame(b = x$stand$nodes$birth, nrr = x$stand$nodes$nrr)
B <- nod(rdx(a[2])); I <- nod(rdx(a[3])); O <- nod(rdx(a[4]))
et <- edge_table(cs); et <- et[et$gap > 22 & et$spell > 22, ]
f <- function(D, b) approx(D$b, log(D$nrr), b)$y
r <- data.frame(b = et$b, open = et$opening, edge = f(B, et$b), inside = f(I, et$b + ifelse(et$opening, 10, -10) / 365),
  gapside = f(O, et$b + ifelse(et$opening, -10, 10) / 365), hat_in = f(B, et$b + ifelse(et$opening, 10, -10) / 365))
r$d_edge_inside <- r$edge - r$inside; r$d_hat <- r$hat_in - r$inside; r$d_gapside <- r$gapside - r$edge
for (o in c(TRUE, FALSE)) { z <- r[r$open == o, ]; cat(sprintf("%s %s edges (n %d): ln nrr edge - 10 d inside: med %+.3f, mean |.| %.3f | base hat at 10 d inside - truth: med %+.3f mean|.| %.3f | 10 d into gap - edge: med %+.3f mean|.| %.3f\n",
  paste(a[-1], collapse = "/"), if (o) "opening" else "closing", nrow(z), median(z$d_edge_inside), mean(abs(z$d_edge_inside)), median(z$d_hat), mean(abs(z$d_hat)), median(z$d_gapside), mean(abs(z$d_gapside)))) }
