# After the container restart: every run's OUT, attempt log and side table loads,
# and the attempt log agrees with the OUT's counts.
#   nice -n 10 Rscript DEV/rej_class/check_outputs.R
R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
for (n in c("smoke_n2", "probe_pics_3e-5", "guard_pics_3e-5", "guard_pi_3e-5")) {
  run <- readRDS(file.path(R, "runs", paste0(n, ".rds")))
  a <- readRDS(file.path(R, "runs", paste0("att_", n, ".rds")))
  s <- readRDS(file.path(R, "runs", paste0("side_", n, ".rds")))
  acc <- run$attempts[["accepted"]] + run$attempts[["accepted_at_minimum"]]
  rej <- sum(run$attempts[c("rejected_inaccurate", "rejected_thrown", "rejected_refused")])
  cat(sprintf("%s: J %.9f; OUT accepted %d rejected %d, st rows %d; log rows %d (accepted %d, rejected %d); side rows %d (max row %d); last time %.6f\n",
              n, run$J, acc, rej, nrow(run$st), nrow(a), sum(a$rejected == 0), sum(a$rejected == 1),
              nrow(s), max(s$row), max(run$st$time)))
}
