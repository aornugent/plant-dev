# Checks the smoke run's new attempt-log columns and side table.
#   nice -n 10 Rscript DEV/rej_class/smoke_check.R smoke_n2
R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
name <- commandArgs(TRUE)[1]
a <- readRDS(file.path(R, "runs", paste0("att_", name, ".rds")))
s <- readRDS(file.path(R, "runs", paste0("side_", name, ".rds")))
str(a[, 19:23])
print(table(a$class_switch, useNA = "ifany"))
print(table(from = a$cs_from, to = a$cs_to, useNA = "ifany"))
str(s)
print(head(s))
print(table(from = s$from, to = s$to))
