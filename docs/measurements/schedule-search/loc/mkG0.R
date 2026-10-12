# G0: the pilot's edges; each open gap between them cut into an even number of equal
# intervals, at most b1/16 in the founders' window and 80 d after it (the square law's
# measured range). C0: G0 with every other node of each gap dropped, so every drop is
# central. Gaps short enough for one interval keep no drop.
source("/home/user/plant-dev/harness/schedule/lattice.R")
L <- file.path(DEV, "schedtest/loc")
for (case in commandArgs(TRUE)) {
  p <- pilot_edges(case); ends <- sort(unique(c(0, p$edges, 39.6))); G <- C <- c()
  for (i in seq_len(length(ends) - 1)) { a <- ends[i]; b <- ends[i + 1]
    open <- p$shut((a + b) / 2) < 0.5
    r <- (b - a) / if (b <= p$b1 + 1e-9) p$b1 / 16 else 80 / 365
    n <- if (!open || r <= 1) 1 else 2 * ceiling(r / 2)
    x <- seq(a, b, length.out = n + 1); G <- c(G, x); C <- c(C, x[c(TRUE, n == 1)]) }
  G <- sort(unique(round(G, 10))); C <- sort(unique(round(C, 10)))
  G <- G[G < 39.6]; C <- C[C < 39.6]
  saveRDS(G, file.path(L, sprintf("G0_%s.rds", case))); saveRDS(C, file.path(L, sprintf("C0_%s.rds", case)))
  cat(sprintf("%s: G0 %d nodes, %d dropped in C0\n", case, length(G), length(G) - length(C)))
}
