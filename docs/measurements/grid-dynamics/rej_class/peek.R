# A first look at the runs' and attempt logs' structure, and plant's control() weights.
#   nice -n 10 Rscript DEV/rej_class/peek.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
run <- readRDS(file.path(D, "pi/runs/pics_3e-5.rds"))
str(run[setdiff(names(run), c("st", "by_node", "rain"))], max.level = 1)
str(run$st)
print(head(run$st))
a <- readRDS(file.path(D, "pi/runs/att_pics_3e-5.rds"))
str(a)
print(head(a, 3))
suppressMessages(library(odelia, lib.loc = file.path(D, "lib_v12t")))
suppressMessages(library(plant, lib.loc = file.path(D, "lib_v12t")))
ct <- control()
print(unlist(ct[grep("^ode_", names(ct))]))
