# a10: a09's committed schedule with every shut gap shorter than G days centred in
# [FROM, 25) spanned by one interval, every open spell keeping at least its start edge;
# a09's check is kept whole. Prints job lines for one.sh.
#   Rscript mka10.R CASE...   (env G = 10, FROM = 10)
source("/home/user/plant-dev/harness/schedule/lattice.R"); L <- file.path(DEV, "schedtest/loc")
G <- as.numeric(Sys.getenv("G", 10)); FROM <- as.numeric(Sys.getenv("FROM", 10))
for (case in commandArgs(TRUE)) { pe <- pilot_edges(case); e <- sort(round(pe$edges, 10)); S <- readRDS(file.path(L, sprintf("loc_a09_c_%s.rds", case)))
  m <- (head(e, -1) + e[-1]) / 2; gap <- pe$shut(m) > 0.5 & diff(e) * 365 < G & m >= FROM & m < 25
  drop <- unique(c(e[-length(e)][gap], e[-1][gap])); k <- which(gap)
  drop <- setdiff(drop, e[k[(k + 2) %in% k] + 1])  # a spell whose gaps both merge keeps its start edge
  x <- S[!(round(S, 10) %in% drop)]
  cap <- function(b) if (b < pe$b1) pe$b1 / 12 else if (b < 20) 100 / 365 else 280 / 365
  for (j in which(gap)) { i <- findInterval(m[j], x); if (i >= 1 && i < length(x) && x[i + 1] - x[i] > cap(m[j])) x <- sort(c(x, m[j])) }
  f <- file.path(L, sprintf("loc_a10_c_%s.rds", case)); saveRDS(x, f)
  cat(sprintf("%s: %d gaps merged, %d of %d nodes kept\n", case, sum(gap), length(x), length(S)), file = stderr())
  j <- grep(sprintf("^val_a09_c_%s ", case), readLines(file.path(L, "jobs_a09.txt")), value = TRUE)
  cat(sub(" TIMES=[^ ]*", paste0(" TIMES=", f), sub("^val_a09_c_", "val_a10_c_", j)), "\n", sep = "") }
