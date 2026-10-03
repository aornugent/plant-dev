# Queue lines for task 2's follow-ups on arkc (METHOD=ark TOL_SOIL=100 SOIL_EST=chain):
# lane A, the nudge rungs at 2.85e-5 and 3.15e-5 and their frozen replays; lane B, the
# constant record at 3e-5 and the frozen replays of the 3e-5 program. Frozen replays are
# THETA_AFTER=1 central differences, u 1e-4 for lma, a_dG1, a_dG2 and 1e-3 for d_I.
#   Rscript t2_lines.R   (writes t2/queue_a.txt and t2b/queue.txt)
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P <- file.path(D, "phase1a")
opts <- "METHOD=ark TOL_SOIL=100"
U <- c(lma = "1e-4", a_dG1 = "1e-4", a_dG2 = "1e-4", d_I = "1e-3")
frozen <- function(k) unlist(lapply(names(U), function(th) vapply(c("+", "-"), function(s)
  sprintf("fz_arkc_%s_%s_%s %s PROGRAM=%s/t2/runs/arkc_%s.rds THETA=%s THETA_REL=%s%s THETA_AFTER=1 TOL=%s ATOL=1e-4 OUT=%s/t2/frozen/arkc_%s_%s_%s.rds",
          k, th, s, opts, P, k, th, if (s == "+") "" else "-", U[[th]], k, P, k, th, s), "")))
a <- c(vapply(c("2.85e-5", "3.15e-5"), function(k)
  sprintf("arkc_%s %s SOIL_EST=chain TOL=%s ATOL=1e-4 OUT=%s/t2/runs/arkc_%s.rds", k, opts, k, P, k), ""),
  frozen("2.85e-5"), frozen("3.15e-5"))
b <- c(sprintf("const_arkc_3e-5 REGIME=constant TIMES=%s/pi/const_times.rds %s SOIL_EST=chain TOL=3e-5 ATOL=1e-4 OUT=%s/t2/runs/const_arkc_3e-5.rds",
               D, opts, P), frozen("3e-5"))
writeLines(a, file.path(P, "t2/queue_a.txt"))
writeLines(b, file.path(P, "t2b/queue.txt"))
cat(length(a), "lines in lane A,", length(b), "in lane B\n")
