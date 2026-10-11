# Constant start: u54, 16 even nodes over the founders' window [0, front), nodes every
# 1/512 day from 0.01 day before the located front to 0.05 day after, and spacing
# doubling outward from the band on both sides until it reaches 2 days.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
fr <- readRDS(file.path(S, "front/base_front.rds")); b0 <- (fr$lo + fr$hi) / 2; d <- 1 / 365
band <- seq(b0 - 0.01 * d, b0 + 0.05 * d, by = d / 512)
h <- d / 512 * 2^(1:10); left <- min(band) - cumsum(h); right <- max(band) + cumsum(h)
s <- c(seq(0, 53 * 40 / 54, length.out = 54), seq(0, b0, length.out = 17)[-17], band, left[left > 0], right)
s <- sort(unique(s)); s <- s[c(TRUE, diff(s) > 1e-9)]
saveRDS(s, file.path(S, "start/s16_th0_constant.rds"))
cat(sprintf("front %.4f d: %d nodes, %d in the band, %d graded\n", b0 * 365, length(s), length(band), sum(left > 0) + length(right)))
print(round(365 * s[s < 0.15], 3))
