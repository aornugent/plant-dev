# Cost model only (edges after 25 left out of both runs, as a09 does): T = 3c + f for
# a09's check and for c04's check (no refinement after 25), per training case.
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/lib.R")
C4 <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/c04_nolate.R", C4)
tot <- c(0, 0)
for (cs in TRAIN) { cd <- prepare(cs); p <- cd$pilot; pr <- a05_pair(p); late <- round(p$edges[p$edges > 25], 10)
  trim <- function(S) S[!(round(S, 10) %in% late)]
  k4 <- C4$fill_before(p, pr$h, pr$Sc, build_graded(p, function(b) if (b < 25) pr$h(b) / C4$R else pr$h(b)))
  c <- cost_of(cd, trim(pr$Sc)); fa <- cost_of(cd, trim(pr$Sk)); f4 <- cost_of(cd, trim(k4)); tot <- tot + c(3 * c + fa, 3 * c + f4)
  cat(sprintf("%-13s c %.0f | a09 check %.0f (%.2f c), T %.0f | c04 check %.0f (%.2f c), T %.0f\n", cs, c, fa, fa / c, 3 * c + fa, f4, f4 / c, 3 * c + f4)) }
cat(sprintf("training five: a09 %.0f, a09 + c04 check %.0f (%.1f%%)\n", tot[1], tot[2], 100 * (tot[2] / tot[1] - 1)))
