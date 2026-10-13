# c05_graded made cheaper: both its schedules lose the edges after b = 25, and run at
# tolerance 1e-4. Prints job lines for one.sh from c05_graded's own job file.
source("/home/user/plant-dev/harness/schedule/lattice.R"); L <- file.path(DEV, "schedtest/loc")
jobs <- readLines(file.path(L, "jobs_c5g.txt"))
for (j in jobs) { w <- strsplit(trimws(j), " ")[[1]]; nm <- w[1]; case <- sub("^val_c5g_[cf]_", "", nm)
  S <- readRDS(file.path(L, sub("^val_", "loc_", paste0(nm, ".rds")))); e <- round(pilot_edges(case)$edges, 10)
  x <- S[!(round(S, 10) %in% e & S > 25)]; f <- file.path(L, sub("^val_c5g", "loc_c5t", paste0(nm, ".rds"))); saveRDS(x, f)
  w[1] <- sub("^val_c5g", "val_c5t", nm); w <- sub("^TIMES=.*", paste0("TIMES=", f), w); w <- w[!grepl("^TOL=", w)]
  cat(paste(c(w, "TOL=1e-4", paste0("LIB=", file.path(DEV, "schedtest/adjmap/lib18"))), collapse = " "), "\n", sep = "")
  cat(sprintf("%s: %d of %d nodes kept\n", case, length(x), length(S)), file = stderr()) }
