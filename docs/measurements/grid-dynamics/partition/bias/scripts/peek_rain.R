D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
a <- readRDS(file.path(D, "ark", "ck_u108_1e-7.rds")); cat("ref has rain:", !is.null(a$rain), "\n")
b <- readRDS(file.path(D, "split", "out", "mono_3e-5.rds")); cat("mono has rain:", !is.null(b$rain), length(b$rain), "knots", length(b$knots), "\n")
print(head(b$rain, 20))
