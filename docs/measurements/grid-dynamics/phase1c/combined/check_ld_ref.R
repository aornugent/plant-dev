# lib_sw with no weights at 1e-5 on long drought (stand alone) against the
# assessment's ld_1e-5 reference: J and the step count.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
a <- readRDS(file.path(WT, "docs/measurements/nudges/ld_1e-5.rds"))
b <- readRDS(file.path(D, "phase1c/combined/full/chk_ld_1e-5_forward.rds"))
cat(sprintf("reference: J %.15g, %s steps, attempts %s\n", a$stand$J, format(a$steps),
            paste(names(a$attempts), unlist(a$attempts), sep = "=", collapse = " ")))
cat(sprintf("lib_sw:    J %.15g, %d steps, attempts %s\n", b$stand$J, length(b$stand$times),
            paste(names(b$stand$attempts), unlist(b$stand$attempts), sep = "=", collapse = " ")))
cat("J identical:", identical(a$stand$J, b$stand$J), "\n")
