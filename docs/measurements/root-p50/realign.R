# H with each first-pass closing moved to the nearest closing of H's own run (its
# creation record at root_P50 x1.02 and x0.98 averaged), then the late ladder again.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs")
edges <- function(cr) { op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths); data.frame(b = cr$end[e][-length(e)], closing = op[e][-length(e)]) }
f1 <- edges(readRDS(file.path(Q, "m_th0_f_dry.rds"))$stand$creation); fh <- edges(readRDS(file.path(Q, "rp_H_0.02_dry.rds"))$stand$creation)
h <- readRDS(file.path(S, "rp50/H_dry.rds")); b1 <- 3.529
cl1 <- f1$b[f1$closing & f1$b > b1]; clh <- fh$b[fh$closing & fh$b > b1]
moved <- 0; shift <- c()
for (c0 in cl1) { k <- which.min(abs(h - c0)); if (abs(h[k] - c0) > 1e-9) next; n <- clh[which.min(abs(clh - c0))]
  if (abs(n - c0) < 5 / 365) { h[k] <- n; moved <- moved + 1; shift <- c(shift, (n - c0) * 365) } }
h <- sort(h); saveRDS(h, file.path(S, "rp50/Hr_dry.rds"))
c <- readRDS(file.path(S, "rp50/C_dry.rds")); hr_keep <- h[vapply(h, function(z) min(abs(readRDS(file.path(S, "rp50/Clate_dry.rds")) - z)) < 1e-9 | z %in% h[!(h %in% readRDS(file.path(S, "rp50/H_dry.rds")))], TRUE)]
# late-only coarsening and bisections of the realigned H, by the same rule as before
d0 <- setdiff(round(readRDS(file.path(S, "rp50/H_dry.rds")), 10), round(readRDS(file.path(S, "rp50/Clate_dry.rds")), 10))
clate <- h[!(round(h, 10) %in% d0)]; m <- head(h, -1) + diff(h) / 2; bl <- sort(c(h, m[m > b1])); m2 <- head(bl, -1) + diff(bl) / 2; bl2 <- sort(c(bl, m2[m2 > b1]))
saveRDS(clate, file.path(S, "rp50/Crlate_dry.rds")); saveRDS(bl, file.path(S, "rp50/BHrlate_dry.rds")); saveRDS(bl2, file.path(S, "rp50/BH2rlate_dry.rds"))
cat(sprintf("closings moved: %d of %d (median shift %.2f d, max %.2f d); nodes H %d, Clate %d, BHlate %d, BH2late %d\n", moved, length(cl1), median(abs(shift)), max(abs(shift)), length(h), length(clate), length(bl), length(bl2)))
