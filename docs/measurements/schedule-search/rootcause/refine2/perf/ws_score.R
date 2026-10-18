# The warm-start A/B: CPU by arm, and how far the hinted runs' quantities and the replay's
# estimate move from the unhinted ones, in eps units.   Rscript ws_score.R CASE [PREFIX]
a <- commandArgs(TRUE); CASE <- a[1]; PRE <- if (length(a) > 1) a[2] else "WS"
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/refine2perf/wsab"
source("/home/user/plant-dev/harness/schedule/quantities.R")
arms <- c("off1", "on1", "on2", "off2")
r <- setNames(lapply(arms, function(k) readRDS(file.path(O, sprintf("%s_%s_%s.rds", PRE, CASE, k)))), arms)
for (k in arms) {
  x <- r[[k]]
  cat(sprintf("%-5s level0 fwd %6.1f sweep %6.1f | replay fwd %6.1f sweep %6.1f | total %6.1f | steps %d\n", k,
              x$level0$cpu[["forward"]], x$level0$cpu[["sweep"]], x$replay$cpu[["forward"]], x$replay$cpu[["sweep"]],
              sum(x$level0$cpu) + sum(x$replay$cpu), x$level0$meta$steps))
}
tot <- function(k, part) { x <- r[[k]]; switch(part, fwd = x$level0$cpu[["forward"]] + x$replay$cpu[["forward"]],
  sweep = x$level0$cpu[["sweep"]] + x$replay$cpu[["sweep"]], all = sum(x$level0$cpu) + sum(x$replay$cpu)) }
for (part in c("fwd", "sweep", "all"))
  cat(sprintf("on / off, %s: %.3f (pairs %.3f, %.3f)\n", part, (tot("on1", part) + tot("on2", part)) / (tot("off1", part) + tot("off2", part)),
              tot("on1", part) / tot("off1", part), tot("on2", part) / tot("off2", part)))
q <- function(k, run) quantities(r[[k]][[run]])
e <- function(k) (q(k, "replay") - q(k, "level0")) / 3 / eps_vec(names(q(k, "level0")))
d0 <- (q("on1", "level0") - q("off1", "level0")) / eps_vec(names(q("off1", "level0")))
dr <- (q("on1", "replay") - q("off1", "replay")) / eps_vec(names(q("off1", "replay")))
de <- e("on1") - e("off1")
cat(sprintf("off arms identical: %s\n", identical(r$off1$level0$stand$elasticity, r$off2$level0$stand$elasticity)))
cat(sprintf("hinted - unhinted, eps units: level 0 worst %.3f (%s) rms %.3f; replay worst %.3f rms %.3f; estimate e worst %.3f rms %.3f\n",
            max(abs(d0)), names(d0)[which.max(abs(d0))], sqrt(mean(d0^2)), max(abs(dr)), sqrt(mean(dr^2)), max(abs(de)), sqrt(mean(de^2))))
