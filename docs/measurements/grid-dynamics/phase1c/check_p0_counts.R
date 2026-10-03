# P0, the two fields that differ: which counts, and the control field.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
a <- readRDS(file.path(D, "window/drv/episodic_rule.rds"))
b <- readRDS(file.path(D, "phase1c/drv/episodic_ruleA_check.rds"))
ka <- names(a$counts); kb <- names(b$counts)
cat("counts only in the old run:", setdiff(ka, kb), "\n")
cat("counts only in the new run:", setdiff(kb, ka), "\n")
for (k in intersect(ka, kb)) if (!identical(a$counts[[k]], b$counts[[k]]))
  cat(sprintf("count %s: %s vs %s\n", k, format(a$counts[[k]]), format(b$counts[[k]])))
cat("order identical:", identical(ka, kb), "; values identical after sorting:",
    identical(a$counts[sort(ka)], b$counts[sort(kb)]), "\n")
cat("control: old", if (is.null(a$control)) "absent" else a$control, ", new", b$control, "\n")
