# P0: the driver with HMAX unset against the window phase's rule-A run on
# episodic, field by field. The old run predates the driver's CONTROL and
# CHAIN_GUARD options, so its OUT lacks the `control` field and the `guarded`
# count; every field and count both hold must be identical.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
a <- readRDS(file.path(D, "window/drv/episodic_rule.rds"))
b <- readRDS(file.path(D, "phase1c/drv/episodic_ruleA_check.rds"))
shared <- setdiff(intersect(names(a), names(b)), c("secs", "counts"))
for (k in shared) cat(sprintf("%-10s %s\n", k, if (identical(a[[k]], b[[k]])) "identical" else "DIFFERS"))
kc <- setdiff(intersect(names(a$counts), names(b$counts)), "secs")
cat(sprintf("counts     %d shared, %s\n", length(kc),
            if (identical(a$counts[kc], b$counts[kc])) "identical" else "DIFFER"))
cat("only in the new OUT:", setdiff(names(b), names(a)), "| new counts:",
    paste(setdiff(names(b$counts), names(a$counts)), unlist(b$counts[setdiff(names(b$counts), names(a$counts))]), sep = " = "), "\n")
cat(sprintf("steps %d vs %d; J %.15g vs %.15g; member evaluations %.0f vs %.0f\n",
            nrow(a$st), nrow(b$st), a$J, b$J, a$counts$members, b$counts$members))
