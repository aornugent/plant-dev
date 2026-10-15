# s1b.R: the whole run's f_hi roots by the step rule (S1b): chatter and where they fall.
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
L <- grep("^JTROOT", readLines(file.path(O, Sys.getenv("ERR", "S1b_census.err"))), value = TRUE)
r <- do.call(rbind, lapply(strsplit(L, " "), function(z) { v <- z[-1]; setNames(as.numeric(v[seq(2, length(v), 2)]), v[seq(1, length(v), 2)]) }))
r <- as.data.frame(r); r$dir <- sign(r$v1 - r$v0)
k <- paste(r$t0, r$node); multi <- table(k); cat("roots", nrow(r), "in", length(unique(r$t0)), "steps;", sum(multi > 1), "node-steps with 2+ roots (pair rule: in and out within a step)\n")
cat("into BoundaryCrit (f_hi up)", sum(r$v1 > r$v0 & r$v0 < 0), " out of it", sum(r$v0 >= 0), "\n")
st <- aggregate(node ~ t0 + h, r, length); st$h_d <- st$h * 365
cat("steps holding roots: h (days) quantiles\n"); print(quantile(st$h_d, c(.1, .5, .9, 1)))
cat("roots per step: quantiles\n"); print(quantile(st$node, c(.5, .9, 1)))
cat("steps holding roots, by length: <1 d", sum(st$h_d < 0.999), ", =1 d (knots)", sum(abs(st$h_d - 1) < 1e-3), ", >1 d", sum(st$h_d > 1.001), "\n")
cat("chattering node-steps, first ten:\n"); print(head(r[k %in% names(multi)[multi > 1], c("t0", "h", "node", "u", "v0", "v1")], 10))
