# Partial refinements of uniform 108 for the per-panel test: the midpoints of a
# few panels only. Each holds at most one extra node per panel, so it nests.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
u108 <- readRDS(file.path(A, "ref", "t_u108.rds"))
mid <- head(u108, -1) + diff(u108) / 2
dir.create(file.path(A, "sched"), showWarnings = FALSE)
w <- function(b, name) saveRDS(sort(unique(b)), file.path(A, "sched", paste0("t_", name, ".rds")))
w(c(u108, mid[1:2]), "u108_p12")      # the top: panels [0, 0.37], [0.37, 0.74]
w(c(u108, mid[3:10]), "u108_p3to10")  # b from 0.74 to 3.70
w(c(u108, mid[11:30]), "u108_p11to30")  # b from 3.70 to 11.1
cat(sprintf("%d, %d, %d nodes\n", length(c(u108, mid[1:2])), length(c(u108, mid[3:10])), length(c(u108, mid[11:30]))))
print(range(mid[3:10])); print(range(mid[11:30]))
