# score_any with rooting_depth_max set aside, as recruitment_decay is.
source("/home/user/plant-dev/harness/schedule/anyscore.R")
EXCLUDED <<- c(EXCLUDED, "rooting_depth_max"); rm(list = ls(CASEDATA), envir = CASEDATA)
a <- commandArgs(TRUE); env <- new.env(); sys.source(a[1], env); ok <- c(); tot <- c()
for (d in 1:as.integer(a[2])) { STRESS <<- d; rr <- evaluate_any(function(ctx) env$algorithm(ctx)); ok <- c(ok, rr$feasible); tot <- c(tot, rr$T) }
cat(sprintf("%s: feasible on %d of %d draws, T %.0f-%.0f\n", basename(a[1]), sum(ok), length(ok), min(tot), max(tot)))
