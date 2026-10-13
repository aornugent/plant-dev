# a11: a09's check refined only before b = 25; after 25 it keeps the committed run's
# nodes, so the late region carries the same error in both runs. Prints job lines for one.sh.
#   Rscript mka11.R CASE...   (env LATE = 25)
source("/home/user/plant-dev/harness/schedule/lattice.R"); L <- file.path(DEV, "schedtest/loc"); LATE <- as.numeric(Sys.getenv("LATE", 25))
for (case in commandArgs(TRUE)) { Sc <- readRDS(file.path(L, sprintf("loc_a09_c_%s.rds", case))); Sk <- readRDS(file.path(L, sprintf("loc_a09_f_%s.rds", case)))
  x <- sort(unique(round(c(Sk[Sk < LATE], Sc[Sc >= LATE]), 10)))
  f <- file.path(L, sprintf("loc_a11_f_%s.rds", case)); saveRDS(x, f)
  cat(sprintf("%s: check %d of %d nodes (committed %d)\n", case, length(x), length(Sk), length(Sc)), file = stderr())
  j <- grep(sprintf("^val_a09_f_%s ", case), readLines(file.path(L, "jobs_a09.txt")), value = TRUE)
  cat(sub(" TIMES=[^ ]*", paste0(" TIMES=", f), sub("^val_a09_f_", "val_a11_f_", j)), "\n", sep = "") }
