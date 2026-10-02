# The "other" rejections within a day of a knot: which accepted step after the knot they
# follow, the rain change there, and the ratio sequence before them.
#   Rscript other_look.R name
P <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi"
source(file.path(P, "analyse.R"))
name <- commandArgs(TRUE)[1]
x <- load_run(name); a <- x$a; run <- x$run
d <- classify(run, a)
knots <- sort(unique(run$knots))
DAY <- 1 / 365
rain <- run$rain
rain_at <- function(t) rain[pmin(pmax(floor(t / DAY + 1e-9) + 1, 1), length(rain))]
k <- findInterval(a$t0 + 1e-12, knots)
kt <- ifelse(k > 0, knots[pmax(k, 1)], NA)
before <- rain_at(kt - 0.5 * DAY); after <- rain_at(kt + 0.5 * DAY)
change <- ifelse(before == 0 & after > 0, "starts", ifelse(before > 0 & after == 0, "stops",
                 ifelse(after > before, "rises", "falls")))
acc <- a$rejected == 0
# accepted steps since the knot, at each attempt's start
n_since <- ave(as.numeric(acc), k, FUN = function(v) c(0, cumsum(v)[-length(v)]))
o <- d$rej & d$cls == "other" & d$since > 0.001 & d$since <= 1
cat(sprintf("%s: other within a day of a knot %d\n", name, sum(o)))
cat("accepted steps since the knot:\n"); print(table(pmin(n_since[o], 6)))
cat("rain change at that knot:\n"); print(table(change[o]))
cat("for comparison, all first attempts there, rejected share by accepted steps since the knot:\n")
f <- a$try == 1 & d$since > 0.001 & d$since <= 1
print(round(tapply(a$rejected[f], pmin(n_since[f], 6), mean), 3))
cat("ratio of the accepted step before, 10/50/90%:", signif(quantile(a$r_set[o], c(.1, .5, .9), na.rm = TRUE), 3),
    "; growth 10/50/90%:", signif(quantile(a$f_set[o], c(.1, .5, .9), na.rm = TRUE), 3),
    "; rejected ratio 10/50/90%:", signif(quantile(a$ratio[o], c(.1, .5, .9), na.rm = TRUE), 3), "\n")
