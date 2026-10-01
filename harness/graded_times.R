# The node schedules of docs/measurements/creation-grid.md, written to OUT as files
# for harness/run_record.R's TIMES. The creation edges below are read off each
# record's creation record (run_record.R's stand$creation) on a pilot run: uniform
# 108 nodes on long drought and wet, the first spacing split 32 ways on the
# constant record.
#
#   Rscript harness/graded_times.R OUT
out <- commandArgs(TRUE)[1]
DAY <- 40 / 14600
U108 <- seq(0, 107 * 40 / 108, length.out = 108)
# The first gap in creation (no establishment) on long drought and wet; on the
# constant record the founders' front, the first window's close and the second's
# opening.
GAP <- list(ld = c(3.5587, 3.7309), wet = c(3.5591, 3.7305))
FRONT <- 23.5 * DAY
CLOSE <- 5.20
REOPEN <- 11.11

# From `from`, a first spacing d1 growing by r per panel up to `cap`, short of `to`.
graded <- function(from, d1, r, cap, to) {
  b <- from; d <- d1
  while (tail(b, 1) + d < to - 1e-9) { b <- c(b, tail(b, 1) + d); d <- min(d * r, cap) }
  b
}
uniform <- function(from, to, h) seq(from, to, length.out = max(2, round((to - from) / h) + 1))
# Every panel halved but the one spanning the gap.
halve <- function(b, gap) {
  m <- head(b, -1) + diff(b) / 2
  sort(c(b, m[!(m > gap[1] & m < gap[2])]))
}
write <- function(b, name) saveRDS(sort(unique(b)), file.path(out, paste0("t_", name, ".rds")))

# Long drought and wet: the first window geometric from 0.03, nodes at the first
# gap's edges and none inside it, then 108 uniform's nodes; G2 to G4 halve G1.
for (r in names(GAP)) {
  g <- sort(unique(c(graded(0, 0.03, 1.11, 0.37, GAP[[r]][1]), GAP[[r]], U108[U108 > 3.75])))
  for (k in 1:4) { write(g, sprintf("%s_G%d", r, k)); g <- halve(g, GAP[[r]]) }
}

# Long drought's other ladders, each nested in the next: uniform; G0, every other
# node of G1 with the gap's edges kept; D, uniform at 0.185 then 0.0926 before
# the gap and 108 then 215 uniform after it; De, D with the gap's edges and
# nothing inside it; Gn, G1 without the edges and with 108 uniform's node inside
# the gap, and every panel of that halved.
U <- function(n) seq(0, 107 * 40 / 108, length.out = n)
for (n in c(108, 215, 429)) write(U(n), sprintf("u%d", n))
gap <- GAP$ld
G1 <- sort(unique(c(graded(0, 0.03, 1.11, 0.37, gap[1]), gap, U108[U108 > 3.75])))
write(G1[seq_along(G1) %% 2 == 1 | G1 %in% gap], "ld_G0")
D <- list(c(U(215)[U(215) < 3.74], U108[U108 >= 3.74]), c(U(429)[U(429) < 3.74], U(215)[U(215) >= 3.74]))
edges <- function(b) c(b[!(b > gap[1] & b < gap[2])], gap)
Gn1 <- sort(c(G1[!(G1 %in% gap)], U108[U108 > gap[1] & U108 < gap[2]]))
for (k in 1:2) { write(D[[k]], sprintf("ld_D%d", k)); write(edges(D[[k]]), sprintf("ld_De%d", k)) }
write(Gn1, "ld_Gn1")
write(c(Gn1, head(Gn1, -1) + diff(Gn1) / 2), "ld_Gn2")

# The constant record. Ten panels growing by 1.18 from a day reach the front; then
# 1.4 per panel up to `cap`, to the first window's close; nothing in the gap; the
# second window uniform at `h2`. The reply's rule as written stops at the front.
front <- cumsum(c(0, DAY * 1.18^(0:9)))
window1 <- function(cap) graded(tail(front, 1), DAY * 1.18^10, 1.4, cap, CLOSE)
causal <- function(cap, h2) c(front, window1(cap), CLOSE, uniform(REOPEN, tail(U108, 1), h2))
at_front <- function(h) seq(20, 26, by = h) * DAY
split_first <- function(k) c(U108, seq_len(k - 1) * U108[2] / k)
U215 <- seq(0, 107 * 40 / 108, length.out = 215)
write(front, "const_lit")
write(causal(0.37, 0.37), "const_Ga")
write(causal(0.37, 1.48), "const_Gb")
write(causal(0.74, 0.74), "const_Gc")
for (k in c(2, 4, 8)) write(c(causal(0.37, 0.37), at_front(1 / k)), sprintf("const_Gf%d", k))
for (k in c(8, 16, 32)) write(c(causal(0.37, 1.48), at_front(1 / k)), sprintf("const_Gbf%d", k))
write(split_first(32), "const_s32")
write(split_first(128), "const_s128")
write(c(seq(0, U108[2], length.out = 129), U215[U215 > U108[2]]), "const_R1")
