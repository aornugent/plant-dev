# Own (interpolation + establishment) and field parts of the measured moves C - P and
# P - B (panel_moves on nested grids), by birth region, in eps of ln J.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
Q <- file.path(D, "schedtest/placed2/runs")
for (nm in c("u108e_episodic_p1", "u108e_episodic_p3", "s16_dry_p3")) {
  xp <- run(paste0("ref_", nm)); xc <- readRDS(file.path(Q, paste0("rc_C_", nm, ".rds"))); xb <- readRDS(file.path(Q, paste0("rc_B_", nm, ".rds")))
  P <- nd(xp); C <- nd(xc); B <- nd(xb)
  mv <- function(a, b) { pm <- panel_moves(a, b); J <- sum(a$w * a$offspring); data.frame(birth = a$birth, own = (pm$interpolation + pm$establishment) / J, field = pm$field / J) }
  cp <- mv(C, P); pb <- mv(P, B)   # each is (coarser -> finer); C - P = -(cp), P - B = -(pb)
  br <- c(0, 1, 3.7, 10, 41)
  tab <- function(m) rbind(own = tapply(-m$own, cut(m$birth, br), sum), field = tapply(-m$field, cut(m$birth, br), sum)) / 0.025
  a <- tab(cp); b <- tab(pb)
  cat(sprintf("\n%s: C-P own %+.3f field %+.3f | P-B own %+.3f field %+.3f | ratios own %.2f field %.2f\n", nm,
    sum(-cp$own) / .025, sum(-cp$field) / .025, sum(-pb$own) / .025, sum(-pb$field) / .025, sum(cp$own) / sum(pb$own), sum(cp$field) / sum(pb$field)))
  print(round(rbind(`C-P` = a, `P-B` = b, ratio = a / b), 3))
}
