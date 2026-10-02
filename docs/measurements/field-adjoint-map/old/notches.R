# Are the old g's notches the establishment gate? E(b) from the current u429 run's
# creation record (same record, seed 31), at the old u429 nodes where g dips.
ADJ <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/perf/adjoint"
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
F <- read.csv(file.path(ADJ, "out", "nodes_uniform_429.csv"))
cr <- readRDS(file.path(A, "ref", "ld_u429_full.rds"))$stand$creation
E_at <- function(b) { i <- findInterval(b, cr$start); ifelse(i >= 1, cr$rate[pmax(i, 1)], NA) }
# E averaged over +-3 days around each node
E_win <- function(b, d = 3 / 365) vapply(b, function(x) { i <- which(cr$end > x - d & cr$start < x + d)
  if (!length(i)) return(NA); sum(cr$rate[i] * (pmin(cr$end[i], x + d) - pmax(cr$start[i], x - d))) / (2 * d) }, 0)
sel <- F$b >= 4.5 & F$b <= 10
d <- data.frame(b = F$b[sel], g = F$g[sel], f = F$f[sel], E = E_at(F$b[sel]), E6d = E_win(F$b[sel]))
options(width = 150)
print(d, digits = 3, row.names = FALSE)
# correlation of f with E over all old nodes
all <- data.frame(b = F$b, f = F$f, E = E_at(F$b))
cat(sprintf("over all 429 nodes: cor(f, E) = %.3f; nodes with E < 0.01: %d, their mean |g| %.4f vs others %.4f\n",
            cor(all$f, all$E, use = "complete"), sum(all$E < 0.01, na.rm = TRUE),
            mean(abs(F$g[which(all$E < 0.01)])), mean(abs(F$g[which(all$E >= 0.01)]))))
# fraction of time the gate is shut (E < 1% of its max) in b < 20, and run lengths
grid <- seq(0, 20, by = 1 / 365); Eg <- E_at(grid)
shut <- Eg < 0.01 * max(Eg, na.rm = TRUE)
r <- rle(shut)
cat(sprintf("b < 20: gate shut %.1f%% of days; %d shut spans, median length %.0f days, %d longer than 0.37 yr\n",
            100 * mean(shut, na.rm = TRUE), sum(r$values), median(r$lengths[r$values]), sum(r$lengths[r$values] > 0.37 * 365)))
