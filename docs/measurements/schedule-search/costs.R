suppressMessages(source("/home/user/plant-dev/harness/schedule/surrogate.R")); STRESS <<- 0
pts <- list(c(16,70), c(16,140), c(32,70), c(64,70), c(32,35), c(64,35), c(16,35), c(32,17.5))
m <- sapply(names(CASES), function(cs) { lib <- load_library(cs); sapply(pts, function(p) run_cost(lookup(lib, p[1], p[2])$rows, TRUE)) })
rownames(m) <- sapply(pts, paste, collapse = "/"); print(round(m))
