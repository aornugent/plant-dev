# Establishment rate inside the long spells of C and D: dips that stay above the 0.01 threshold.
SP <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad"; O <- file.path(SP, "refine/s05/epi-adG208")
S <- readRDS("schedules.rds")$s05
for (nm in c("first", "level1_forward")) { er <- readRDS(file.path(O, paste0(nm, ".rds")))$stand$establishment
  cat("\n", nm, ": rate quantiles over open steps", round(quantile(er$rate[er$rate > 0.01], c(.05, .25, .5, .75)), 3), "\n")
  for (p in S$panels) { if (p$n < 1 || p$lo < 6.6 || p$lo >= 17.7) next
    k <- er$start >= p$lo & er$end <= p$hi; if (!any(k)) next
    r <- er$rate[k]; t <- er$start[k]; inner <- t > p$lo + 5 / 365 & t < p$hi - 5 / 365
    m <- median(r); lo <- if (any(inner)) min(r[inner]) else NA
    cat(sprintf("panel %.3f-%.3f n %d: median rate %.3f, min inside (5 d from edges) %.4f at %.3f, steps below 0.2 median %d\n",
      p$lo, p$hi, p$n, m, lo, if (any(inner)) t[inner][which.min(r[inner])] else NA, sum(inner & r < 0.2 * m))) } }
