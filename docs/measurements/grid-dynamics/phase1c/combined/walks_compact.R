# Every walk of the bounded and ARK runs in one table: J' per invader, or RAISED.
C <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1c/combined/full"
invs <- c("lma=0.5", "lma=0.7", "lma=1.4", "lma=2", "hmat=0.5", "hmat=0.7", "hmat=1.4", "hmat=2")
runs <- c("bnd_ld", "arkA_ld", "arkB_ld", "bnd_wet", "arkA_wet", "arkB_wet", "bnd_epi", "arkA_epi", "arkB_epi")
tab <- sapply(runs, function(k) {
  x <- readRDS(file.path(C, paste0(k, ".rds")))
  vapply(invs, function(i) if (!is.null(x$failures[[i]])) "RAISED" else if (is.null(x$invaders[[i]])) "-" else
    sprintf("%.4g", x$invaders[[i]]$J), "")
})
print(noquote(tab))
