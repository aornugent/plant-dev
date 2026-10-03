# The structure of the tol 1e-7 reference run and its saved states.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/ark"
r <- readRDS(file.path(D, "ck_u108_1e-7.rds"))
str(r[setdiff(names(r), c("st", "by_node", "rain"))])
str(r$st)
s <- readRDS(file.path(D, "ck_u108_1e-7_states.rds"))
cat("states:", length(s), "; lengths of first, 100th, last:", length(s[[1]]), length(s[[100]]), length(s[[length(s)]]), "\n")
cat("rows in st:", nrow(r$st), "\n")
