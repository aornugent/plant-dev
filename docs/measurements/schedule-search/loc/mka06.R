# a06: a05's two schedules with the edges a run does not need taken out of both: every
# edge after b = 25, and both edges of each shut gap under 10 d, except that a spell
# whose gaps merge on both sides keeps its start edge. Where a merged interval would pass
# the range, the gap's later edge goes back. Prints job lines for one.sh.
#   Rscript mka06.R CASE...
source("/home/user/plant-dev/harness/schedule/lattice.R"); L <- file.path(DEV, "schedtest/loc")
trim <- function(S, pe) { e <- sort(round(pe$edges, 10)); m <- (head(e, -1) + e[-1]) / 2
  gap <- pe$shut(m) > 0.5 & diff(e) * 365 < 10; k <- which(gap); both <- k[(k + 2) %in% k]
  drop <- setdiff(unique(c(e[-length(e)][gap], e[-1][gap])), e[both + 1]); drop <- c(drop, e[e > 25])
  x <- S[!(round(S, 10) %in% round(drop, 10))]
  cap <- function(b) if (b < pe$b1) pe$b1 / 12 else if (b < 20) 100 / 365 else 280 / 365
  for (j in k) { i <- findInterval(m[j], x); if (i >= 1 && i < length(x) && x[i + 1] - x[i] > cap(m[j])) x <- sort(c(x, e[j + 1])) }
  x }
jobs <- readLines(file.path(L, "jobs_a04t.txt"))
for (case in commandArgs(TRUE)) { pe <- pilot_edges(case)
  for (r in c("c", "f")) { S <- readRDS(file.path(L, sprintf("loc_a05_%s_%s.rds", r, case))); x <- trim(S, pe)
    f <- file.path(L, sprintf("loc_a06_%s_%s.rds", r, case)); saveRDS(x, f)
    cat(sprintf("%s %s: %d of %d nodes\n", case, r, length(x), length(S)), file = stderr())
    w <- strsplit(trimws(grep(sprintf("^val_a04t_c_%s ", case), jobs, value = TRUE)), " ")[[1]]
    w[1] <- sprintf("val_a06_%s_%s", r, case); w <- sub("^TIMES=.*", paste0("TIMES=", f), w)
    cat(paste(c(w, paste0("LIB=", file.path(DEV, "schedtest/adjmap/lib18"))), collapse = " "), "\n", sep = "") } }
