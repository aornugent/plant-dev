# Where the constant record's rejections fall: Rscript const_look.R name
P <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi"
name <- commandArgs(TRUE)[1]
a <- readRDS(file.path(P, "runs", paste0("att_", name, ".rds")))
r <- readRDS(file.path(P, "runs", paste0(name, ".rds")))
intro <- r$by_node$time
a$since_intro <- a$t0 - intro[findInterval(a$t0 + 1e-12, intro)]
acc <- a[a$rejected == 0, ]
rej <- a[a$rejected == 1, ]
acc$k <- seq_len(nrow(acc))
last_clip <- cummax(ifelse(acc$final == 1, acc$k, 0))
acc$since_clip <- acc$k - last_clip
j <- findInterval(rej$t0, acc$t0, left.open = TRUE)
rej$since_clip <- acc$since_clip[pmax(j, 1)]
s <- rej[!is.na(rej$x_soil) & rej$x_soil >= 0.8, ]
cat(name, ": rejections", nrow(rej), "; at h|lambda|/beta >= 0.8:", nrow(s), "\n")
cat("their times, 0/10/50/90/100%:", signif(quantile(s$t0, c(0, .1, .5, .9, 1)), 3), "\n")
cat("accepted steps since the last clipped step, 10/50/90%:", quantile(s$since_clip, c(.1, .5, .9)), "\n")
cat("days since the last introduction, 10/50/90%:", signif(quantile(s$since_intro * 365, c(.1, .5, .9)), 3), "\n")
cat("rejected: h|lambda|/beta", signif(quantile(s$x_soil, c(.1, .5, .9)), 3), "; ratio", signif(quantile(s$ratio, c(.1, .5, .9)), 3), "\n")
cat("accepted: share at >= 0.8", signif(mean(acc$x_soil >= 0.8), 3), ", > 1", signif(mean(acc$x_soil > 1), 3),
    "; h|lambda|/beta 10/50/90%:", signif(quantile(acc$x_soil, c(.1, .5, .9)), 3), "\n")
st <- acc[acc$t0 > 2, ]
cat("t > 2: accepted", nrow(st), ", rejected", sum(rej$t0 > 2), "; accepted ratio 10/50/90%:", signif(quantile(st$ratio, c(.1, .5, .9)), 3), "\n")
cat("rejections per introduction interval (t > 2), 0/50/90/100%:",
    quantile(table(factor(findInterval(rej$t0[rej$t0 > 2], intro), seq_along(intro))), c(0, .5, .9, 1)), "\n")
for (t in head(s$t0[s$t0 > 5], 2)) {
  w <- a[a$t0 >= t - 10 * median(acc$h) & a$t0 <= t + 4 * median(acc$h),
         c("t0", "h", "ratio", "index", "rejected", "final", "x_soil", "f_set")]
  w$t0 <- signif(w$t0, 8); w$h <- signif(w$h * 365, 4)
  print(w, row.names = FALSE)
}
