# jsplice.R: J0-J3 against the committed inset run at 3e-4 (A) and at 2.85e-4 (B) on dry:
# how far along A -> B each replay lands (projection), and its distance off that line.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
XR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/runs"
qa <- quantities(readRDS(file.path(POUT, "runs", "P_ins3c_dry.rds"))); qb <- quantities(readRDS(file.path(XR, "X_ins3c_2.85e-4_dry.rds")))
k <- intersect(names(qa), names(qb)); e <- eps_vec(k); v <- (qb[k] - qa[k]) / e
cat(sprintf("A -> B: rms %.3f, max %.3f (%s)\n", sqrt(mean(v^2)), max(abs(v)), k[which.max(abs(v))]))
for (j in sprintf("J%d", c(0:10, 12:14))) { f <- file.path(XR, sprintf("X_%s_dry.rds", j)); if (!file.exists(f)) next; x <- readRDS(f); if (is.null(x$stand$elasticity)) next
  w <- (quantities(x)[k] - qa[k]) / e; t <- sum(w * v) / sum(v^2); off <- w - t * v
  cat(sprintf("%s: along A -> B %.2f, off the line rms %.4f (max %.3f); from B rms %.4f\n", j, t, sqrt(mean(off^2)), max(abs(off)), sqrt(mean((w - v)^2)))) }
