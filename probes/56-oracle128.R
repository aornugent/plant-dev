# The oracle row for the paper table, at the best available settings:
#   A = 128 m2, regular arrivals at midpoint placement (2nd-order birth-date
#   quadrature), log-linear snapshot interpolation (measured artefact <= 0.015%),
#   soil water frozen at each end of the SCM's own range -> a bracket.
# Mortality remains stochastic (the only randomness left), so seeds are paired
# between the two soil levels and averaged.
suppressMessages(library(plant)); library(parallel)
source("probes/lib.R"); setwd("/home/user/plant-dev")
TEND <- 3.5; AGES <- c(1, 1.5, 2, 2.5, 3); A <- 128
SOIL <- c(wet = 0.310613, dry = 0.299220)
p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))

one <- function(seed, sw) {
  set.seed(seed); p <- p0; p$patch_area <- A; p$max_patch_lifetime <- TEND
  e <- Environment("TF24"); e$set_soil_water_state(rep(sw, length(e$get_soil_water_state())))
  dt <- 1/A; aa <- seq(0.5*dt, TEND, by = dt)
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, e, Control())
  sc <- plant:::NodeSchedule(1); sc$max_time <- TEND; sc$set_times(aa, 1)
  obj$node_schedule <- sc
  tm <- c(); la <- c()
  snap <- function() { sp <- obj$patch$species[[1]]
    tm <<- c(tm, obj$patch$time); la <<- c(la, sp$compute_competition(0)/A) }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm) & la > 0
  exp(approx(tm[ok], log(la[ok]), AGES, rule=2)$y)
}

seeds <- 4240000L + 1:10
res <- list()
for (sn in names(SOIL)) {
  L <- do.call(rbind, mclapply(seeds, function(s) one(s, SOIL[[sn]]), mc.cores = 2))
  res[[sn]] <- L
  cat(sprintf("soil=%-4s nseed=%-3d %s\n            se     %s\n", sn, nrow(L),
      paste(sprintf("%11.6f", colMeans(L)), collapse=" "),
      paste(sprintf("%11.6f", apply(L,2,sd)/sqrt(nrow(L))), collapse=" ")))
  flush.console()
}
cat(sprintf("\npaired dry/wet ratio (same seeds): %s\n",
    paste(sprintf("%9.5f", colMeans(res$dry/res$wet)), collapse=" ")))
saveRDS(list(res=res, ages=AGES, area=A, soil=SOIL), "probes/out/56-oracle128.rds")

## the table
S <- readRDS("probes/out/54-final.rds")$S
ht <- S[["ht_340"]]; bd <- S[["bd_340"]]
ow <- colMeans(res$wet); od <- colMeans(res$dry)
sw <- apply(res$wet,2,sd)/sqrt(nrow(res$wet))
cat("\n############ TABLE ############\n")
cat(sprintf("%5s | %11s %11s %8s | %11s %12s | %11s %14s\n","age",
    "oracle wet","oracle dry","se(wet)","SCM height","ratio","SCM birthdate","ratio"))
for (i in seq_along(AGES))
  cat(sprintf("%5.1f | %11.6f %11.6f %8.5f | %11.6f %5.2f-%-5.2f | %11.6f %6.3f-%-6.3f\n",
      AGES[i], ow[i], od[i], sw[i], ht[i], ht[i]/ow[i], ht[i]/od[i],
      bd[i], bd[i]/ow[i], bd[i]/od[i]))
