# Round 12: per late interval of H, the map's root_P50 elasticity move at the first and
# second all-late bisections, and their ratio.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
R <- file.path(dirname(A), "rp50"); u <- 0.02; e <- 0.01075
mv <- function(P) { p <- run(sprintf("rpmap_%s_0.02", P)); m <- run(sprintf("rpmap_%s_-0.02", P))
  part <- function(x) { b <- nd(x); own_drop(b, x$dropped) / sum(b$w * b$offspring) + (colSums(x$light) + colSums(x$soil)) / x$stand$J }
  b <- nd(p)$birth[p$dropped]
  list(b = b, move = -(part(p) - part(m)) / (2 * u) / e, el = c(p = log(p$stand$J), m = log(m$stand$J))) }
h <- readRDS(file.path(R, "H_dry.rds")); a <- mv("BHlate"); c2 <- mv("BH2late")
cat(sprintf("map totals: H -> BHlate %+.3f eps, BHlate -> BH2late %+.3f eps (measured on lib_109: -0.32, -0.15)\n", sum(a$move), sum(c2$move)))
i1 <- findInterval(a$b, h); i2 <- findInterval(c2$b, h)
m1 <- tapply(a$move, i1, sum); m2 <- tapply(c2$move, i2, sum)[names(m1)]; m2[is.na(m2)] <- 0
d <- data.frame(i = as.integer(names(m1)), b0 = h[as.integer(names(m1))], len_d = diff(h)[as.integer(names(m1))] * 365, m1 = as.numeric(m1), m2 = as.numeric(m2))
d$r <- d$m2 / d$m1
big <- abs(d$m1) > 0.02
cat(sprintf("intervals %d, with |m1| > 0.02 eps: %d; median m2/m1 there %.3f (quartiles %.3f, %.3f)\n", nrow(d), sum(big), median(d$r[big]), quantile(d$r[big], .25), quantile(d$r[big], .75)))
pos <- d$m1 > 0
cat(sprintf("positive m1: sum m1 %+.3f, sum m2 %+.3f (ratio %.2f) | negative m1: sum m1 %+.3f, sum m2 %+.3f (ratio %.2f)\n",
  sum(d$m1[pos]), sum(d$m2[pos]), sum(d$m1[pos]) / sum(d$m2[pos]), sum(d$m1[!pos]), sum(d$m2[!pos]), sum(d$m1[!pos]) / sum(d$m2[!pos])))
cat(sprintf("sum |m1| %.3f, sum |m2| %.3f\n", sum(abs(d$m1)), sum(abs(d$m2))))
o <- order(-abs(d$m1))[1:15]; print(round(d[o, ], 3))
saveRDS(d, file.path(R, "score12.rds"))
