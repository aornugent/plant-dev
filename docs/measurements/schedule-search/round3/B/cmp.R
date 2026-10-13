source("/home/user/plant-dev/docs/measurements/schedule-search/round3/B/lib_b.R")
P <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/"
for (cs in names(CASES)) { S <- readRDS(file.path(LOC, sprintf("loc_a09_c_%s.rds", cs))); a <- readRDS(sprintf("%sB_thin_%s_0.005_0.05.rds", P, cs)); b <- readRDS(sprintf("%sB_thin_%s_0.005_0.05band.rds", P, cs))
  ra <- setdiff(round(S, 9), round(a, 9)); rb <- setdiff(round(S, 9), round(b, 9)); cat(sprintf("%-13s map-d removed %d, band-d removed %d, common %d\n", cs, length(ra), length(rb), length(intersect(ra, rb))))
  if (cs == "dry") { cat("dry cluster 5.39-5.43 removed by map-d greedy: "); print(ra[ra > 5.39 & ra < 5.44]) } }
