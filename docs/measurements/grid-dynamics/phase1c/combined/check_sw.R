# lib_sw with no weights against lib_guard's own episodic run (spot-check
# epi_base, 3e-5 tied, uniform 108): the stand's J, step times, sizes and attempts.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
a <- readRDS(file.path(WT, "docs/measurements/spot-check/epi_base.rds"))$stand
b <- readRDS(file.path(D, "phase1c/combined/full/chk_epi_forward.rds"))
cat("lib:", b$versions$lib, "plant", b$versions$plant, "odelia", b$versions$odelia, "\n")
b <- b$stand
for (k in c("J", "times", "sizes", "attempts"))
  cat(sprintf("%-9s %s\n", k, if (identical(a[[k]], b[[k]])) "identical" else "DIFFERS"))
cat(sprintf("J %.15g vs %.15g; %d vs %d steps\n", a$J, b$J, length(a$times), length(b$times)))
