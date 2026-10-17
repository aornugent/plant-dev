# lib.R: the H5 layout and the round's shared loaders.
# h5_sched(cs, s, open, d_o): a09's graded build at spacing s x h (the builder's range cap
# scaled by s too), late edges (b > 25) left out as a09_late does, with every edge before 25
# treated by a rule that does not depend on s:
#   closing edge c: a node at c and a node at c - 12 d;
#   (open = "node1": a node at o only; the stretch starts at o. Edges at or after tcut
#   get E6's inset: one node 12 d into the spell, none at the edge.)
#   opening edge o: open = "node":  a node at o (unless the gap before it or the spell is under 2 d) and
#                                    a node at o + 12 d;
#                   open = "inset": no node at o, a node at o + d_o (d_o may be s-scaled by
#                                    the caller).
# Only the stretch between those nodes is placed by the graded measure at s x h, so the
# founders, the interiors and each spell's remaining stretch scale with s. A spell too short
# for its strips keeps its edge nodes and, if longer than 13 d, one node at its centre.
# open = "raw", close = FALSE reproduces build_graded() exactly (the guard).
Sys.setenv(BG = 90, R = 1.6)
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
H5 <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/h5"
D <- 1 / 365
place <- function(a, b, hfun, cp) { u <- seq(a, b, length.out = 801); um <- (head(u, -1) + tail(u, -1)) / 2
  w <- 1 / pmin(vapply(um, hfun, 0), cp); cw <- c(0, cumsum(w * diff(u))); n <- ceiling(tail(cw, 1) - 1e-9)
  if (n <= 1) return(numeric(0))
  x <- if (diff(range(w)) < 1e-12) seq(a, b, length.out = n + 1) else approx(cw / tail(cw, 1), u, seq(0, 1, length.out = n + 1), ties = "ordered")$y
  while (any(diff(x) > cp + 1e-10)) { n <- n + 1; x <- approx(cw / tail(cw, 1), u, seq(0, 1, length.out = n + 1), ties = "ordered")$y }
  x[2:n] }
h5_sched <- function(cs, s, open = c("node", "inset", "raw", "node1"), d_o = 12, close = TRUE, strip = 12, H = 39.6, tcut = 25) {
  open <- match.arg(open); p <- pilot_of(cs); h <- alg$hfun_of(p); hs <- function(b) s * h(b)
  et <- edge_table(cs); ends <- sort(unique(c(0, p$edges, H))); G <- c()
  kind <- function(x) { j <- which(abs(et$b - x) < 1e-9); if (!length(j)) "late" else if (x >= tcut) (if (et$opening[j]) "open_i" else "close_i") else if (et$opening[j]) "open" else "close" }
  gap_before <- function(x) et$gap[abs(et$b - x) < 1e-9]
  for (i in seq_len(length(ends) - 1)) { a <- ends[i]; b <- ends[i + 1]; ka <- if (a == 0) "start" else kind(a); kb <- if (b >= H) "end" else kind(b)
    if (!(ka %in% c("late", "open_i"))) G <- c(G, a)                               # build_graded's segment start; late edges are left out below
    if (p$shut((a + b) / 2) > 0.5) next
    cp <- s * cap_of(p, a, b); L <- (b - a) * 365
    lo <- a; hi <- b; fixed <- c()
    if (open != "raw" && ka == "open") {
      if (open == "node") { if (gap_before(a) < 2 || L < 2) G <- G[abs(G - a) > 1e-9]; lo <- a + strip * D }
      else if (open == "node1") { if (gap_before(a) < 2 || L < 2) G <- G[abs(G - a) > 1e-9] }
      else { G <- G[abs(G - a) > 1e-9]; lo <- a + d_o * D } }
    if (open != "raw" && ka == "open_i") lo <- a + strip * D             # after tcut: E6's inset, one node 12 d in
    if ((close && kb == "close") || kb == "close_i") hi <- b - strip * D
    if (lo > a) fixed <- c(fixed, lo); if (hi < b) fixed <- c(fixed, hi)
    if ((hi - lo) * 365 < 2) {                                   # too short for both strips
      fixed <- c(); if (L > 13 && (ka != "open" || open %in% c("node", "node1"))) fixed <- (a + b) / 2
      if (ka == "open" && open == "inset" && kb == "close" && L > 13) fixed <- b - min(strip, L / 2) * D
      G <- c(G, fixed); next }
    G <- c(G, fixed, place(lo, hi, hs, cp)) }
  if (close) G <- c(G, et$b[!et$opening & et$b < tcut])
  G <- G[!(round(G, 10) %in% round(et$b[!et$opening & et$b >= tcut], 10))]                         # closing edges as nodes (segment ends)
  G <- sort(unique(round(G, 10))); late <- round(p$edges[p$edges > 25], 10); G <- G[!(G %in% late)]
  stopifnot(all(diff(G) > 1e-6)); G }
# Loaders: runs, references, the E6 pair.
ADJ <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
h5_run <- function(nm) { f <- file.path(H5, "runs", paste0(nm, ".rds")); if (!file.exists(f)) return(NULL); x <- readRDS(f); if (is.null(x$stand$elasticity)) return(NULL); x }
