# The long-wet combined run killed by the restart against its rerun: the phases
# both finished must agree bit for bit.
C <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1c/combined/full"
a <- readRDS(file.path(C, "comb_wet_killed.rds")); b <- readRDS(file.path(C, "comb_wet.rds"))
cat("stand J, times, attempts identical:", identical(a$stand$J, b$stand$J), identical(a$stand$times, b$stand$times),
    identical(a$stand$attempts, b$stand$attempts), "\n")
for (k in names(a$invaders)) cat(sprintf("%-9s J' identical: %s\n", k, identical(a$invaders[[k]]$J, b$invaders[[k]]$J)))
