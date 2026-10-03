# Queue lines for a variant's frozen-step central differences (THETA_AFTER=1, partial
# elasticities) on its driver programs, and the nudge-triple driver runs they need.
#   Rscript frozen_lines.R VARIANT "METHOD=ark TOL_SOIL=100" 3e-5 [traits] >> queue.txt
a <- commandArgs(TRUE)
v <- a[1]; opts <- a[2]; w <- as.numeric(a[3])
U <- c(lma = "1e-4", a_dG1 = "1e-4", a_dG2 = "1e-4", d_I = "1e-3")  # amendment 2
traits <- if (length(a) > 3) strsplit(a[4], ",")[[1]] else c("lma", "a_dG1", "a_dG2", "d_I")
P <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1a"
tag <- function(x) sub("e([-+])0*", "e\\1", format(x, scientific = TRUE, digits = 3))
tols <- vapply(w * c(0.95, 1, 1.05), tag, "")
for (k in tols[c(1, 3)]) {
  if (!file.exists(file.path(P, "runs", sprintf("%s_%s.rds", v, k))))
    cat(sprintf("%s_%s SCRIPT=../harness_u/ark_prototype.R %s TOL=%s ATOL=1e-4 OUT=%s/runs/%s_%s.rds\n",
                v, k, opts, k, P, v, k))
}
for (k in tols) for (th in traits) for (s in c("+", "-")) {
  cat(sprintf("fz_%s_%s_%s_%s SCRIPT=../harness_f/ark_prototype.R %s PROGRAM=%s/runs/%s_%s.rds THETA=%s THETA_REL=%s%s THETA_AFTER=1 TOL=%s ATOL=1e-4 OUT=%s/frozen/%s_%s_%s_%s.rds\n",
              v, k, th, s, opts, P, v, k, th, if (s == "+") "" else "-", U[[th]], k, P, v, k, th, s))
}
