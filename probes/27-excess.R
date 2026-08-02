# The corrected solver sits 6% to 21% above the individual-based ensemble's leaf
# area before canopy closure.  Two candidate causes: the birth-date quadrature is
# under-resolved at 141 introductions, or the stochastic ensemble mean of a
# nonlinear functional is not the deterministic value.  The first is testable by
# refining the schedule; the second by adding replicates and checking the mean is
# not simply noisy.
source("probes/lib.R"); suppressMessages(library(dplyr)); setwd("/home/user/plant-dev")
MPL <- 105.32; AGES <- c(1, 1.5, 2, 2.5, 3, 4, 5)
midpoints <- function(tt) sort(unique(c(tt, (head(tt,-1)+tail(tt,-1))/2)))

lai_traj <- function(bd, tt) {
  p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
  p$node_schedule_times <- list(tt)
  ct <- Control(); ct$node_density_in_birth_date <- bd
  scm <- scm_collect(p, "TF24", ct)
  tm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
  la <- vapply(seq_along(scm$history), function(k)
    scm$history[[k]]$species[[1]]$compute_competition(0), 0)
  vapply(AGES, function(a) la[which.min(abs(tm - a))], 0)
}

p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
tt <- p0$node_schedule_times[[1]]
res <- list()
for (lev in 0:2) {
  if (lev > 0) tt <- midpoints(tt)
  t0 <- Sys.time()
  res[[as.character(length(tt))]] <- lai_traj(TRUE, tt)
  cat(sprintf("birth-date, %d introductions: %s   (%.0fs)\n", length(tt),
      paste(sprintf("%.5f", res[[as.character(length(tt))]]), collapse=" "),
      as.numeric(difftime(Sys.time(), t0, units="secs")))); flush.console()
}
saveRDS(list(ages = AGES, scm = res), "probes/out/excess-scm.rds")

o <- readRDS("probes/out/oracle-ibm.rds")
cat("\nages:                        ", paste(sprintf("%7.1f", AGES), collapse=" "), "\n")
for (nm in names(res))
  cat(sprintf("SCM birth-date n=%-4s        %s\n", nm,
      paste(sprintf("%7.5f", res[[nm]]), collapse=" ")))
pooled <- vapply(AGES, function(a) { j <- which.min(abs(o$grid - a))
  mean(c(o$out[["4"]]$L[,j,1], o$out[["16"]]$L[,j,1], o$out[["64"]]$L[,j,1])) }, 0)
cat(sprintf("IBM pooled mean (16 runs)    %s\n", paste(sprintf("%7.5f", pooled), collapse=" ")))
for (nm in names(res))
  cat(sprintf("ratio n=%-4s                 %s\n", nm,
      paste(sprintf("%7.3f", res[[nm]]/pooled), collapse=" ")))
