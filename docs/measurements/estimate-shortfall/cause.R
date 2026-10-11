# Cause attribution: the map on P predicts C - P, the map on B predicts P - B, each
# split into own, light and soil parts and binned by the dropped node's birth date.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
parts <- function(x) { b <- nd(x); j <- x$dropped
  data.frame(birth = b$birth[j], own = own_drop(b, j) / sum(b$w * b$offspring), light = colSums(x$light) / x$stand$J, soil = colSums(x$soil) / x$stand$J) }
br <- c(0, 1, 3.7, 10, 20, 41)
for (nm in c("u108e_episodic_p3", "s16_dry_p3")) {
  xb <- run(paste0("rcB_", nm)); if (is.null(xb$soil)) next
  a <- parts(run(paste0("ref_", nm))); b <- parts(xb)
  tb <- function(d) sapply(c("own", "light", "soil"), function(k) tapply(d[[k]], cut(d$birth, br), sum)) / 0.025
  A <- tb(a); B <- tb(b)
  cat(sprintf("\n%s: C-P own %+.3f light %+.3f soil %+.3f | P-B own %+.3f light %+.3f soil %+.3f\n", nm,
    sum(a$own) / .025, sum(a$light) / .025, sum(a$soil) / .025, sum(b$own) / .025, sum(b$light) / .025, sum(b$soil) / .025))
  cat("C-P by cause region:\n"); print(round(A, 3)); cat("P-B:\n"); print(round(B, 3)); cat("ratio:\n"); print(round(A / B, 2))
}
