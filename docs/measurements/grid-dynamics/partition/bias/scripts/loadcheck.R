lib <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split/lib"
.libPaths(c(lib, .libPaths()))
suppressMessages(library(odelia, lib.loc = lib))
suppressMessages(library(plant, lib.loc = lib))
cat("plant from", find.package("plant"), as.character(packageVersion("plant")), "\n")
cat("odelia from", find.package("odelia"), "\n")
cat("probe:", exists("split_hold_tf24", envir = asNamespace("plant")),
    exists("split_uptake_tf24", envir = asNamespace("plant")), "\n")
