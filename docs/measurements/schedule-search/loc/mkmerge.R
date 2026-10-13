# Short shut gaps spanned by one interval: on a04's committed schedule, both edges of
# every shut gap shorter than G days are dropped, and a node goes at the gap's centre
# only where the merged interval would pass the range. Prints job lines for one.sh.
#   Rscript mkmerge.R G CASE...
source("/home/user/plant-dev/harness/schedule/lattice.R"); L <- file.path(DEV, "schedtest/loc")
a <- commandArgs(TRUE); G <- as.numeric(a[1])
for (case in a[-1]) { pe <- pilot_edges(case); e <- sort(round(pe$edges, 10)); S <- readRDS(file.path(L, sprintf("loc_a04_c_%s.rds", case)))
  m <- (head(e, -1) + e[-1]) / 2; gap <- pe$shut(m) > 0.5 & diff(e) * 365 < G
  drop <- unique(c(e[-length(e)][gap], e[-1][gap])); x <- S[!(round(S, 10) %in% drop)]
  cap <- function(b) if (b < pe$b1) pe$b1 / 12 else if (b < 20) 100 / 365 else 280 / 365
  for (c0 in m[gap]) { i <- findInterval(c0, x); if (i >= 1 && i < length(x) && x[i + 1] - x[i] > cap(c0)) x <- sort(c(x, c0)) }
  f <- file.path(L, sprintf("loc_mg%d_%s.rds", G, case)); saveRDS(x, f)
  cat(sprintf("%s G %d: %d gaps merged, %d of %d nodes kept\n", case, G, sum(gap), length(x), length(S)), file = stderr())
  j <- grep(sprintf("^val_a04t_c_%s ", case), readLines(file.path(L, "jobs_a04t.txt")), value = TRUE)
  w <- strsplit(trimws(j), " ")[[1]]; w[1] <- sprintf("probe_mg%d_%s", G, case); w <- sub("^TIMES=.*", paste0("TIMES=", f), w)
  cat(paste(c(w, paste0("LIB=", file.path(DEV, "schedtest/adjmap/lib18"))), collapse = " "), "\n", sep = "") }
