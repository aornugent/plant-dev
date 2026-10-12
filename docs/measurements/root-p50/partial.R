# root_P50's elasticity (central differences) on partial coarsenings and bisections of H.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); u <- 0.02; eps <- 0.01075
el <- function(g) { a <- readRDS(file.path(Q, sprintf("rp_%s_0.02_dry.rds", g)))$stand$J; b <- readRDS(file.path(Q, sprintf("rp_%s_-0.02_dry.rds", g)))$stand$J; (log(a) - log(b)) / (2 * u) }
e <- sapply(c("C", "Clate", "Cearly", "H", "BHlate", "BHearly", "BH"), el)
f <- function(a, b) (e[b] - e[a]) / eps
cat(sprintf("all:      C -> H %+.2f eps | H -> BH %+.2f eps | ratio %.2f\n", f("C", "H"), f("H", "BH"), f("C", "H") / f("H", "BH")))
cat(sprintf("late:     C -> H %+.2f eps | H -> BH %+.2f eps | ratio %.2f\n", f("Clate", "H"), f("H", "BHlate"), f("Clate", "H") / f("H", "BHlate")))
cat(sprintf("founders: C -> H %+.2f eps | H -> BH %+.2f eps | ratio %.2f\n", f("Cearly", "H"), f("H", "BHearly"), f("Cearly", "H") / f("H", "BHearly")))
cat(sprintf("additivity: late + founders coarsening %+.2f vs all %+.2f; bisections %+.2f vs %+.2f\n", f("Clate", "H") + f("Cearly", "H"), f("C", "H"), f("H", "BHlate") + f("H", "BHearly"), f("H", "BH")))
