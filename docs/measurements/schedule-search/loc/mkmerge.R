# Short shut gaps spanned by one interval: on a04's committed schedule, both edges of
# every shut gap shorter than G days are dropped; where the merged interval would pass
# the range, a node goes back at the gap's centre (KEEP=centre) or its later edge
# (KEEP=edge), the start of the next open spell. Prints job lines for one.sh.
#   Rscript mkmerge.R G CASE...   (FROM, TO: merge only gaps centred in [FROM, TO);
#   SPELLS=1: an open spell whose gaps on both sides merge keeps its start edge;
#   SPELLS=2: no two gaps either side of one spell both merge, so every spell keeps both edges)
source("/home/user/plant-dev/harness/schedule/lattice.R"); L <- file.path(DEV, "schedtest/loc")
a <- commandArgs(TRUE); G <- as.numeric(a[1]); KEEP <- Sys.getenv("KEEP", "centre"); tag <- if (KEEP == "edge") "mk" else "mg"
FROM <- as.numeric(Sys.getenv("FROM", 0)); TO <- as.numeric(Sys.getenv("TO", 40)); if (FROM > 0 || TO < 40) tag <- sprintf("%s%g-%g_", tag, FROM, TO); if (Sys.getenv("SPELLS") %in% c("1", "2")) tag <- paste0(tag, c("1" = "s", "2" = "t")[Sys.getenv("SPELLS")])
for (case in a[-1]) { pe <- pilot_edges(case); e <- sort(round(pe$edges, 10)); S <- readRDS(file.path(L, sprintf("loc_a04_c_%s.rds", case)))
  m <- (head(e, -1) + e[-1]) / 2; gap <- pe$shut(m) > 0.5 & diff(e) * 365 < G & m >= FROM & m < TO
  if (Sys.getenv("SPELLS") == "2") for (k in which(gap)) if (k >= 3 && gap[k - 2]) gap[k] <- FALSE
  drop <- unique(c(e[-length(e)][gap], e[-1][gap]))
  if (Sys.getenv("SPELLS") == "1") { k <- which(gap); both <- k[(k + 2) %in% k]; drop <- setdiff(drop, e[both + 1]) }
  x <- S[!(round(S, 10) %in% drop)]
  cap <- function(b) if (b < pe$b1) pe$b1 / 12 else if (b < 20) 100 / 365 else 280 / 365
  for (j in which(gap)) { c0 <- m[j]; i <- findInterval(c0, x)
    if (i >= 1 && i < length(x) && x[i + 1] - x[i] > cap(c0)) x <- sort(c(x, if (KEEP == "edge") e[j + 1] else c0)) }
  f <- file.path(L, sprintf("loc_%s%d_%s.rds", tag, G, case)); saveRDS(x, f)
  cat(sprintf("%s G %d: %d gaps merged, %d of %d nodes kept\n", case, G, sum(gap), length(x), length(S)), file = stderr())
  j <- grep(sprintf("^val_a04t_c_%s ", case), readLines(file.path(L, "jobs_a04t.txt")), value = TRUE)
  w <- strsplit(trimws(j), " ")[[1]]; w[1] <- sprintf("probe_%s%d_%s", tag, G, case); w <- sub("^TIMES=.*", paste0("TIMES=", f), w)
  cat(paste(c(w, paste0("LIB=", file.path(DEV, "schedtest/adjmap/lib18"))), collapse = " "), "\n", sep = "") }
