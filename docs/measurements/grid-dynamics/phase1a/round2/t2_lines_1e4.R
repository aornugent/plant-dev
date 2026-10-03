# Queue lines for arkc's resident frozen nudge test around 1e-4: the rungs at 9.5e-5 and
# 1.05e-4, and the THETA_AFTER=1 central differences on all three programs (u 1e-4 for
# lma, a_dG1, a_dG2 and 1e-3 for d_I). Appended to lane B's queue.
#   Rscript t2_lines_1e4.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P <- file.path(D, "phase1a")
opts <- "METHOD=ark TOL_SOIL=100"
U <- c(lma = "1e-4", a_dG1 = "1e-4", a_dG2 = "1e-4", d_I = "1e-3")
frozen <- function(k) unlist(lapply(names(U), function(th) vapply(c("+", "-"), function(s)
  sprintf("fz_arkc_%s_%s_%s %s PROGRAM=%s/t2/runs/arkc_%s.rds THETA=%s THETA_REL=%s%s THETA_AFTER=1 TOL=%s ATOL=1e-4 OUT=%s/t2/frozen/arkc_%s_%s_%s.rds",
          k, th, s, opts, P, k, th, if (s == "+") "" else "-", U[[th]], k, P, k, th, s), "")))
l <- c(vapply(c("9.5e-5", "1.05e-4"), function(k)
  sprintf("arkc_%s %s SOIL_EST=chain TOL=%s ATOL=1e-4 OUT=%s/t2/runs/arkc_%s.rds", k, opts, k, P, k), ""),
  frozen("1e-4"), frozen("9.5e-5"), frozen("1.05e-4"))
cat(l, sep = "\n", file = file.path(P, "t2b/queue.txt"), append = TRUE)
cat(length(l), "lines appended to lane B\n")
