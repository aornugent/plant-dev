# Why only ln J matched: the elasticity names and values of a combined run
# against the baseline's.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
a <- readRDS(file.path(WT, "docs/measurements/spot-check/epi_base.rds"))
b <- readRDS(file.path(D, "phase1c/combined/full/comb_epi.rds"))
cat("baseline stand fields:", paste(names(a$stand), collapse = ","), "\n")
cat("combined stand fields:", paste(names(b$stand), collapse = ","), "\n")
cat("baseline names (head):", head(names(a$stand$elasticity), 5), "| n =", length(a$stand$elasticity), "\n")
cat("combined names (head):", head(names(b$stand$elasticity), 5), "| n =", length(b$stand$elasticity), "\n")
cat("combined values (head):", head(b$stand$elasticity, 5), "\n")
cat("combined gradient (head):", head(b$stand$gradient, 5), "\n")
cat("combined value:", b$stand$value, " refusal:", format(b$stand$refusal), "\n")
cat("combined control fields:", paste(names(b$stand$control), collapse = ","), "\n")
print(str(b$stand$control))
