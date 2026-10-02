# Where a partitioned run's error sits: its held collar's deficit at each member
# step's end by the step's length (a STEP_LOG run), and each run's difference
# in J from the monolithic run by the members' birth dates.
#
#   Rscript where.R mono.rds held.rds run.rds [run2.rds ...]
#
# mono.rds is split_stepper.R's MONO=1 OUT; held.rds a COUPLING=held run with
# STEP_LOG=1.
args <- commandArgs(TRUE)
m <- readRDS(args[1])$by_node
cm <- m$weight * m$fecundity * m$patch_density
L <- readRDS(args[2])$steplog
h <- vapply(L, `[[`, 0, "h") * 365
rel_end <- vapply(L, function(x) sum(x$defect[5, ]) / sum(x$true_up[5, ]), 0)
g <- cut(h, c(0, 0.3, 1, 3, 10, 100))
cat(sprintf("== %s: the held collar's deficit at each member step's end, over the uptake there, by the step's length in days\n",
            basename(args[2])))
print(data.frame(steps = as.vector(table(g)), median = tapply(rel_end, g, median),
                 q90 = tapply(rel_end, g, quantile, 0.9)), digits = 3)
for (f in args[-1]) {
  p <- readRDS(f)$by_node
  d <- p$weight * p$fecundity * p$patch_density - cm
  band <- cut(p$time, c(-1, 0.5, 3.6, 10, 100), labels = c("born before 0.5", "0.5-3.6", "3.6-10", "after 10"))
  cat(sprintf("%s: J %+.3g relative; shares of the difference %s; the first two members' output %s relative\n",
              basename(f), sum(d) / sum(cm),
              paste(sprintf("%s %.2f", levels(band), tapply(d, band, sum) / sum(d)), collapse = ", "),
              paste(sprintf("%+.3g", p$fecundity[1:2] / m$fecundity[1:2] - 1), collapse = " and ")))
}
