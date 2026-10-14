# trace.R: parse a libD sweep's PARAMS (cumulative trait adjoint after each step, from T
# back) and LAMBDA rows; saves JT_out/NAME_trace.rds. Args: NAME...
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
for (nm in commandArgs(TRUE)) {
  L <- readLines(file.path(O, paste0(nm, ".err")))
  pr <- strsplit(sub("^PARAMS ", "", grep("^PARAMS ", L, value = TRUE)), " ")
  P <- do.call(rbind, lapply(pr, as.numeric))
  lr <- strsplit(sub("^LAMBDA ", "", grep("^LAMBDA ", L, value = TRUE)), " ")
  lam <- lapply(lr, as.numeric)
  saveRDS(list(params = P, lambda = lam), file.path(O, paste0(nm, "_trace.rds")))
  cat(nm, ": ", nrow(P), " PARAMS rows of width ", ncol(P), ", ", length(lam), " LAMBDA rows\n", sep = "")
}
