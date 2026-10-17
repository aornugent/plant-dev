# guard_map.R NAME CASE: a map run on the scratch build against E6's saved libS check run
# (same schedule, 1e-4): J, step times and the 50 trait gradients identical().
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R")
a <- commandArgs(TRUE); x <- readRDS(file.path(RO, "runs", paste0(a[1], ".rds"))); b <- e6_runs(a[2])$x1
cat(sprintf("%s: J identical %s; times identical %s; gradients identical %s; map %s\n", a[1], identical(x$stand$J, b$stand$J),
  identical(x$stand$times, b$stand$times), identical(unname(x$stand$gradient), unname(b$stand$gradient)),
  paste(sprintf("%s %+.3f", names(summ(a[2], x, TRUE)$map), summ(a[2], x, TRUE)$map), collapse = ", ")))
cat(sprintf("cpu fwd %.0f sweep %.0f; rows %.0f\n", x$stand$cpu, x$sweep_cpu, x$stand$rows))
