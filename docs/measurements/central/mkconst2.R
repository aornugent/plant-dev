# Constant start: the default ladder's early grading (node_schedule_times_default) up to
# 0.37 yr spacing, then 0.37 yr; nodes every 1/512 day from 0.01 day before the located
# front to 0.05 day after; spacing graded outward from that band by x1.5 until it meets
# the ladder. Nodes of the ladder inside the graded zone are dropped.
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
fr <- readRDS(file.path(S, "front/base_front.rds")); b0 <- (fr$lo + fr$hi) / 2; d <- 1 / 365
dft <- plant::node_schedule_times_default(40); dft <- dft[c(TRUE, diff(dft) > 1e-12)]
lad <- dft[dft <= 1]; lad <- c(lad, seq(max(lad) + 0.37, 39.6, by = 0.37))
band <- seq(b0 - 0.01 * d, b0 + 0.05 * d, by = d / 512)
gaps <- function(n0, h0) { h <- h0 * 1.5^(1:n0); cumsum(h) }
left <- min(band) - gaps(40, d / 512); right <- max(band) + gaps(40, d / 512)
spacing_at <- function(t) { i <- findInterval(t, lad); ifelse(i >= 1 & i < length(lad), lad[pmin(i + 1, length(lad))] - lad[pmax(i, 1)], 0.37) }
# keep graded nodes while their spacing is finer than the ladder's there
lh <- c(diff(rev(c(left, min(band))))); left <- left[left > 0]; left <- left[seq_along(left)][(d / 512 * 1.5^(seq_along(left))) < spacing_at(left)]
right <- right[(d / 512 * 1.5^(seq_along(right))) < spacing_at(right)]
zone <- c(min(c(left, band)), max(c(right, band)))
s <- sort(unique(c(lad[lad < zone[1] | lad > zone[2]], left, band, right))); s <- s[c(TRUE, diff(s) > 1e-12)]
saveRDS(s, file.path(S, "hier/dyc_th0_constant.rds"))
cat(sprintf("front %.4f d: %d nodes (%d ladder kept, %d band, %d graded), graded zone %.2f-%.2f d\n", b0 * 365, length(s),
  sum(lad < zone[1] | lad > zone[2]), length(band), length(left) + length(right), zone[1] * 365, zone[2] * 365))
print(round(365 * s[s < 0.2], 3))
