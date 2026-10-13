# Which saved runs carry a drop map, and how many of their dropped nodes are pilot edges.
source("/home/user/plant-dev/harness/schedule/lattice.R")
A <- file.path(DEV, "schedtest/adjmap/runs")
x <- readRDS(file.path(A, "loc_G0_dry.rds")); str(x, max.level = 1); str(x$stand, max.level = 1)
fs <- list.files(A, "\\.rds$")
for (f in fs) { y <- tryCatch(readRDS(file.path(A, f)), error = function(e) NULL); if (is.null(y)) next
  if (identical(y$mode, "map") && length(y$dropped)) cat(sprintf("%-40s n %4d dropped %4d case %s\n", f, length(y$node_times), length(y$dropped), paste(y$case, y$record, collapse = "/"))) }
