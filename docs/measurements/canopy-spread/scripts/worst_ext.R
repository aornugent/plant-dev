# The quantities with the largest extrapolated errors (eps) for rung pairs, against
# the graded reference. Usage: Rscript worst_ext.R name=coarse.rds,fine.rds ...
src <- readLines("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb/scripts/pair_scores.R")
eval(parse(text = src[1:grep("^ref <- ", src)]))
for (a in commandArgs(TRUE)) {
  kv <- strsplit(a, "=")[[1]]; f <- strsplit(kv[2], ",")[[1]]
  qa <- quantities(readRDS(f[1])); qb <- quantities(readRDS(f[2]))
  k <- Reduce(intersect, list(names(qa), names(qb), names(ref))); k <- k[!(sub("^(resident|invader) ", "", k) %in% small)]
  ext <- qb[k] + (qb[k] - qa[k]) / 3 - ref[k]
  o <- head(order(-abs(ext)), 6)
  cat(sprintf("%-16s %s\n", kv[1], paste(sprintf("%s %+.3f", k[o], ext[o]), collapse = "; ")))
}
