# The top crown (born 0) on two field_snap2.R runs at matching times: canopy
# density, the first gap's crown-overlap ratio, and the crown-mean light m and its
# response to the crown's own height dm/dln h, lumped (as plant builds the field)
# and spread, with the share of dm the crown's own panel supplies.
# Usage: Rscript top_crown.R coarse.rds fine.rds
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb/scripts/field_lib.R")
f <- commandArgs(TRUE); xa <- readRDS(f[1]); xb <- readRDS(f[2])
one <- function(s, M = 0, skip = 0) {
  h <- s$height[1]; d <- 1e-4
  E <- function(z) exp(-field_A(s, z, M = M, skip = skip))
  c(m = crown_mean(E, h, s$eta),
    dm = (crown_mean(E, h * exp(d), s$eta) - crown_mean(E, h * exp(-d), s$eta)) / (2 * d))
}
rows <- lapply(seq_along(xa$snaps), function(i) {
  a <- xa$snaps[[i]]; b <- xb$snaps[[i]]
  la <- one(a); lb <- one(b); sa <- one(a, M = 8); sb <- one(b, M = 8); na <- one(a, skip = 1)
  x <- function(s) (s$height[1] - s$height[2]) / (s$height[1] / s$eta)
  data.frame(t = a$time, A0 = a$A[1], x_coarse = x(a), x_fine = x(b),
             m_lumped_move = lb[["m"]] - la[["m"]], m_spread_move = sb[["m"]] - sa[["m"]],
             dm_lumped_coarse = la[["dm"]], dm_lumped_rel_move = (lb[["dm"]] - la[["dm"]]) / la[["dm"]],
             dm_spread_rel_move = (sb[["dm"]] - sa[["dm"]]) / sa[["dm"]],
             own_panel_share_coarse = 1 - na[["dm"]] / la[["dm"]])
})
print(signif(do.call(rbind, rows), 3), row.names = FALSE)
