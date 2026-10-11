# Rain onsets inside open creation windows: rises in layer-1 water of more than 0.05,
# by the water before the rise, from the first pass's own soil record (u54).
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
onsets <- function(x, rise = 0.05) {
  s <- x$stand$soil; cr <- x$stand$creation; rate <- approxfun(cr$start, cr$rate, method = "constant", rule = 2)
  th <- s$theta[, 1]; tt <- s$time; i <- which(diff(th) > 0.01) + 1
  st <- i[c(TRUE, diff(tt[i]) > 2 / 365)]                       # one onset per rise
  before <- th[pmax(1, st - 1)]; peak <- vapply(st, function(k) max(th[k:min(length(th), k + 20)]), 0)
  d <- data.frame(t = tt[st], before = before, jump = peak - before, open = rate(tt[st] - 1e-6) > 0.01)
  d[d$jump > rise & d$t > 0 & d$t < 40, ] }
x <- readRDS(file.path(S, "placed2/runs/m_th0_f_episodic.rds")); d <- onsets(x)
cat(sprintf("onsets with a rise > 0.05: %d; inside open windows %d (of which after water < 0.2: %d)\n", nrow(d), sum(d$open), sum(d$open & d$before < 0.2)))
saveRDS(d, file.path(S, "rc/onsets_episodic.rds"))
y <- readRDS(file.path(S, "placed2/runs/fwd_u108e_p3_episodic.rds")); d3 <- onsets(y)
near <- vapply(d$t[d$open], function(z) min(abs(d3$t - z)), 0) * 365
cat(sprintf("first-pass open onsets vs pass-3 run's: median %.3f d, > 1 d: %d\n", median(near), sum(near > 1)))
