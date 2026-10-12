# Height increments of the panel's cohorts between successive short runs, by birth
# date: their shape across the panel (normalised to the panel mean) and curvature.
.libPaths(c("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_109", .libPaths()))
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
t3 <- readRDS(file.path(S, "refine/ref_u108e_episodic_p3_times.rds"))
L <- c(9, 10, 11, 12, 14, 17, 20)
H <- sapply(L, function(l) { n <- readRDS(file.path(S, sprintf("placed2/runs/rc_life%d_episodic.rds", l)))$stand$nodes
  k <- which(n$birth >= 7.985 & n$birth <= 8.52 & !(round(n$birth, 9) %in% round(t3, 9)) | round(n$birth, 6) %in% round(c(7.985226, 8.518519), 6)); n$height[k] })
n <- readRDS(file.path(S, "placed2/runs/rc_life20_episodic.rds"))$stand$nodes
b <- n$birth[which(n$birth >= 7.985 & n$birth <= 8.52 & !(round(n$birth, 9) %in% round(t3, 9)) | round(n$birth, 6) %in% round(c(7.985226, 8.518519), 6))]
q <- round(seq(1, length(b), length.out = 14))
for (i in seq_along(L)[-1]) { g <- H[, i] - H[, i - 1]; r <- g / mean(g)
  cat(sprintf("growth %2d-%2d: mean %.3f m; relative growth across the panel:", L[i - 1], L[i], mean(g)), paste(sprintf("%.3f", r[q]), collapse = " "), "\n") }
cat("birth dates:", paste(sprintf("%.3f", b[q]), collapse = " "), "\n")
